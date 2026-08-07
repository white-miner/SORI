import 'package:flutter/material.dart';

import '../models/customer.dart';
import 'customer_list_page.dart';
import 'home_page.dart';
import 'message_history_page.dart';
import 'my_app.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;

  final List<Customer> _customers = [
    Customer(
      id: '1',
      name: '김민지',
      phone: '010-1234-5678',
      lastTreatmentDate: DateTime(2026, 8, 5),
      treatmentType: '재생케어',
      memo: '두피 민감, 자연 펌 선호',
    ),
    Customer(
      id: '2',
      name: '이수진',
      phone: '010-2345-6789',
      lastTreatmentDate: DateTime(2026, 8, 3),
      treatmentType: '수분케어',
      memo: '정기 예약 고객',
    ),
    Customer(
      id: '3',
      name: '박서연',
      phone: '010-3456-7890',
      lastTreatmentDate: DateTime(2026, 7, 28),
      treatmentType: '재생케어',
      memo: '트리트먼트 관심 많음',
    ),
  ];

  void _addCustomer(Customer customer) {
    setState(() {
      _customers.insert(0, customer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MyHomePage(customers: _customers),
          CustomerListPage(
            customers: _customers,
            onCustomerAdded: _addCustomer,
          ),
          const MessageHistoryPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: MyApp.soriPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: '고객 관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: '메시지 이력',
          ),
        ],
      ),
    );
  }
}
