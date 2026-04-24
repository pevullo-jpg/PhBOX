import 'package:flutter/material.dart';
import 'side_menu.dart';

class AppScaffold extends StatelessWidget {

  final Widget child;
  final int pageIndex;
  final Function(int) onNavigate;

  const AppScaffold({
    super.key,
    required this.child,
    required this.pageIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideMenu(
            pageIndex: pageIndex,
            onNavigate: onNavigate,
          ),
          Expanded(child: child)
        ],
      ),
    );
  }
}
