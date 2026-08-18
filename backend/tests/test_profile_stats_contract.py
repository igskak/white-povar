"""The profile counters must count what the app actually shows.

The three totals sit next to a collection screen the user can open, so the
tests here pin the two ways they could lie: counting rows from another tenant,
and never recording a scan at all.
"""
import asyncio
import base64
import io
from types import SimpleNamespace

from PIL import Image

from app.api.v1.endpoints import auth, search
from app.core.tenant import TenantContext
from app.services.database import supabase_service


def _user():
    return auth.User(id='user-a', email='a@example.com')


def _tenant():
    return TenantContext(slug='tenant-a', chef_id='chef-a')


class _FakeQuery:
    """Records the filter chain PostgREST would receive."""

    def __init__(self, table, log, rows, counts):
        self._table = table
        self._log = log
        self._rows = rows
        self._counts = counts
        self._filters = []
        self._negate = False

    def select(self, columns, count=None):
        self._count_mode = count
        return self

    def eq(self, column, value):
        self._filters.append(('eq', column, value))
        return self

    def in_(self, column, values):
        self._filters.append(('in', column, tuple(values)))
        return self

    @property
    def not_(self):
        self._negate = True
        return self

    def is_(self, column, value):
        self._filters.append(('not.is' if self._negate else 'is', column, value))
        self._negate = False
        return self

    def limit(self, count):
        return self

    def execute(self):
        self._log.append((self._table, tuple(self._filters)))
        return SimpleNamespace(
            data=self._rows.get(self._table, []),
            count=self._counts.get(self._table, 0),
        )


def _fake_client(log, rows, counts):
    return SimpleNamespace(table=lambda name: _FakeQuery(name, log, rows, counts))


def test_saved_total_counts_only_recipes_the_saved_page_can_list(monkeypatch):
    log = []
    rows = {'user_favorites': [{'recipe_id': 'recipe-in'}, {'recipe_id': 'recipe-elsewhere'}]}
    counts = {'recipes': 1, 'user_recipe_history': 4, 'user_scan_events': 7}
    monkeypatch.setattr(
        supabase_service, 'get_client', lambda use_service_key=False: _fake_client(log, rows, counts)
    )

    stats = asyncio.run(supabase_service.get_profile_stats('user-a', 'chef-a'))

    # Two favorites, one of which belongs to another tenant: the saved total is
    # the tenant-filtered count, not the raw junction-table row count.
    assert stats == {'saved': 1, 'cooked': 4, 'scans': 7}
    queried = dict(log)
    assert queried['recipes'] == (
        ('in', 'id', ('recipe-in', 'recipe-elsewhere')), ('eq', 'chef_id', 'chef-a'),
    )
    assert queried['user_recipe_history'] == (
        ('eq', 'user_id', 'user-a'), ('eq', 'chef_id', 'chef-a'),
        ('not.is', 'cooked_at', 'null'),
    )
    assert queried['user_scan_events'] == (
        ('eq', 'user_id', 'user-a'), ('eq', 'chef_id', 'chef-a'),
    )


def test_saved_total_is_zero_without_favorites_and_never_queries_recipes(monkeypatch):
    log = []
    monkeypatch.setattr(
        supabase_service, 'get_client',
        lambda use_service_key=False: _fake_client(log, {}, {}),
    )

    stats = asyncio.run(supabase_service.get_profile_stats('user-a', 'chef-a'))

    assert stats == {'saved': 0, 'cooked': 0, 'scans': 0}
    # An unfiltered `in_([])` would match the whole catalog on some backends.
    assert 'recipes' not in dict(log)


def test_saved_and_cooked_survive_an_unmigrated_scan_table(monkeypatch):
    """The scan table ships in a migration applied after the code deploys."""

    def client(use_service_key=False):
        real = _fake_client([], {'user_favorites': []}, {'user_recipe_history': 2})

        def table(name):
            if name == 'user_scan_events':
                raise RuntimeError('relation "user_scan_events" does not exist')
            return real.table(name)

        return SimpleNamespace(table=table)

    monkeypatch.setattr(supabase_service, 'get_client', client)

    stats = asyncio.run(supabase_service.get_profile_stats('user-a', 'chef-a'))

    assert stats == {'saved': 0, 'cooked': 2, 'scans': 0}


def test_stats_endpoint_reads_the_resolved_tenant(monkeypatch):
    calls = []

    async def stats(user_id, chef_id):
        calls.append((user_id, chef_id))
        return {'saved': 1, 'cooked': 2, 'scans': 3}

    monkeypatch.setattr(auth.supabase_service, 'get_profile_stats', stats)

    result = asyncio.run(auth.get_profile_stats(_user(), _tenant()))

    assert (result.saved, result.cooked, result.scans) == (1, 2, 3)
    assert calls == [('user-a', 'chef-a')]


def _png_base64():
    """A small but non-uniform image: a flat colour compresses below the
    endpoint's minimum byte size and is rejected before any scan logic runs."""
    image = Image.new('RGB', (32, 32))
    image.putdata([(x * 8 % 256, y * 8 % 256, (x + y) % 256)
                   for y in range(32) for x in range(32)])
    buffer = io.BytesIO()
    image.save(buffer, format='PNG')
    return base64.b64encode(buffer.getvalue()).decode()


def _stub_vision(monkeypatch, ingredients):
    async def analyze(image):
        return {'ingredients': ingredients, 'confidence': 0.9}

    async def find(ingredients, chef_id, max_results):
        return []

    monkeypatch.setattr(search.openai_service, 'analyze_ingredients', analyze)
    monkeypatch.setattr(search, '_find_recipes_by_ingredients', find)


def _scan(monkeypatch, current_user, ingredients=('tomato',)):
    recorded = []

    async def record(user_id, chef_id):
        recorded.append((user_id, chef_id))

    _stub_vision(monkeypatch, list(ingredients))
    monkeypatch.setattr(search.supabase_service, 'record_scan_event', record)
    from app.schemas.search import PhotoSearchRequest

    asyncio.run(search.search_by_photo(
        PhotoSearchRequest(image=_png_base64()), current_user, _tenant(),
    ))
    return recorded


def test_scan_is_recorded_for_the_signed_in_account(monkeypatch):
    assert _scan(monkeypatch, _user()) == [('user-a', 'chef-a')]


def test_anonymous_scan_stays_anonymous(monkeypatch):
    assert _scan(monkeypatch, None) == []


def test_unreadable_photo_does_not_count_as_a_scan(monkeypatch):
    assert _scan(monkeypatch, _user(), ingredients=()) == []


def test_a_failed_write_still_returns_the_scan_results(monkeypatch):
    async def explode(user_id, chef_id):
        raise RuntimeError('supabase unavailable')

    _stub_vision(monkeypatch, ['tomato'])
    monkeypatch.setattr(search.supabase_service, 'record_scan_event', explode)
    from app.schemas.search import PhotoSearchRequest

    response = asyncio.run(search.search_by_photo(
        PhotoSearchRequest(image=_png_base64()), _user(), _tenant(),
    ))

    assert response.ingredients == ['tomato']
