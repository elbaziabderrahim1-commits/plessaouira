import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const StaffManagementApp());
}

class StaffManagementApp extends StatelessWidget {
  const StaffManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة موظفي السجن',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}

class Employee {
  final String id;
  String name;
  String workCenter;
  String restDays;
  String status; 
  String phone;

  Employee({
    required this.id, required this.name, required this.workCenter, 
    required this.restDays, this.status = 'في الخدمة', this.phone = '',
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'workCenter': workCenter, 'restDays': restDays, 'status': status, 'phone': phone};
  factory Employee.fromJson(Map<String, dynamic> json) => Employee(id: json['id'], name: json['name'], workCenter: json['workCenter'], restDays: json['restDays'], status: json['status'], phone: json['phone'] ?? '');
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  void _login() {
    if (_pinController.text == "1234") {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز خاطئ')));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.security, size: 80), const SizedBox(height: 20), SizedBox(width: 200, child: TextField(controller: _pinController, obscureText: true, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: 'الرمز السري'))), ElevatedButton(onPressed: _login, child: const Text('دخول'))]))));
  }
}

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});
  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? staffJson = prefs.getString('prison_staff_final');
    if (staffJson != null) {
      final List<dynamic> decodedList = jsonDecode(staffJson);
      setState(() { _employees = decodedList.map((item) => Employee.fromJson(item)).toList(); _isLoading = false; });
    } else {
      setState(() { _employees = _getInitialEmployees(); _isLoading = false; });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prison_staff_final', jsonEncode(_employees.map((e) => e.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('إدارة الموظفين')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _employees.length,
        itemBuilder: (context, index) {
          final emp = _employees[index];
          return Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: emp.status == 'في الخدمة' ? Colors.green : Colors.orange, child: Text(emp.name[0])),
            title: Text(emp.name),
            subtitle: Text(emp.workCenter),
            trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editStatus(emp)),
          ));
        },
      ),
    ));
  }

  void _editStatus(Employee emp) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text(emp.name),
      content: DropdownButton<String>(
        value: emp.status,
        items: ['في الخدمة', 'راحة', 'رخصة'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) { setState(() { emp.status = v!; }); _saveData(); Navigator.pop(context); },
      ),
    ));
  }

  List<Employee> _getInitialEmployees() {
    return [
      Employee(id: '1', name: 'خلفاوي الحسين', workCenter: 'رئيس المعقل', restDays: 'السبت-الأحد'),
      Employee(id: '2', name: 'زكرياء الكفيش', workCenter: 'نائب رئيس المعقل', restDays: 'السبت-الأحد'),
    ];
  }
}
