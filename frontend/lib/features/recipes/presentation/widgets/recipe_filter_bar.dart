import 'package:flutter/material.dart';

class RecipeFilterBar extends StatelessWidget {
  const RecipeFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isSelected: true,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Featured',
              isSelected: false,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Quick (< 30 min)',
              isSelected: false,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Mediterranean',
              isSelected: false,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Mexican',
              isSelected: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
