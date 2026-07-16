"""Best-effort product telemetry that cannot affect a consumer journey."""
import logging

from app.services.database import supabase_service

logger = logging.getLogger(__name__)


async def emit_analytics(user_id: str, chef_id: str, name: str, outcome: str = 'success') -> None:
    try:
        await supabase_service.record_analytics_event(user_id, chef_id, name, outcome)
    except Exception:
        # Observability must never turn a completed product action into failure.
        logger.warning('Analytics event dropped: %s', name, exc_info=True)
