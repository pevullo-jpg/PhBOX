import 'package:flutter/material.dart';

class HeaderBar extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final ValueChanged<String> onChanged;

  const HeaderBar({
    super.key,
    required this.title,
    required this.searchController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(
            width: 360,
            child: TextField(
              controller: searchController,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Cerca nome, CF, città, medico',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF151515),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
