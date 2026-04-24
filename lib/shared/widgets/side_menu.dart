import 'package:flutter/material.dart';

class SideMenu extends StatelessWidget {

  final int pageIndex;
  final Function(int) onNavigate;

  const SideMenu({
    super.key,
    required this.pageIndex,
    required this.onNavigate,
  });

  Widget tile(int index, IconData icon, String label){

    final selected = pageIndex == index;

    return ListTile(
      leading: Icon(
        icon,
        color: selected ? Colors.amber : Colors.white70,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () => onNavigate(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: const Color(0xFF070707),
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            'Farmacia Desk',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),

          tile(0, Icons.dashboard, 'Dashboard'),
          tile(1, Icons.people, 'Assistiti'),
          tile(2, Icons.description, 'Ricette'),
          tile(3, Icons.receipt_long, 'Debiti'),
          tile(4, Icons.medication, 'Anticipi'),
          tile(5, Icons.calendar_month, 'Prenotazioni'),
          tile(6, Icons.warning, 'Scadenze'),
          tile(7, Icons.settings, 'Impostazioni'),
        ],
      ),
    );
  }
}
