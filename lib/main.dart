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
      title: 'إدارة موظفي السجن المحلي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
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
    required this.id,
    required this.name,
    required this.workCenter,
    required this.restDays,
    this.status = 'في الخدمة',
    this.phone = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'workCenter': workCenter,
        'restDays': restDays,
        'status': status,
        'phone': phone,
      };

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'],
        name: json['name'],
        workCenter: json['workCenter'],
        restDays: json['restDays'],
        status: json['status'] ?? 'في الخدمة',
        phone: json['phone'] ?? '',
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final String _correctPin = "1234";

  void _login() {
    if (_pinController.text == _correctPin) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز السري خاطئ!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text('نظام إدارة أمن المؤسسة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _pinController,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'الرمز السري'),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _login, child: const Text('دخول')),
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> _employees = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? staffJson = prefs.getString('prison_staff_v4');
    if (staffJson != null) {
      final List<dynamic> decodedList = jsonDecode(staffJson);
      setState(() {
        _employees = decodedList.map((item) => Employee.fromJson(item)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _employees = _getInitialEmployees();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_employees.map((e) => e.toJson()).toList());
    await prefs.setString('prison_staff_v4', encodedData);
  }

  void _generateReport(String type) {
    String report = "";
    String dateStr = "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
    if (type == 'daily') {
      var list = _employees.where((e) => e.status == 'في الخدمة').toList();
      report = "📋 *تقرير الحضور اليومي ($dateStr)*\n\n✅ المتواجدون (${list.length}):\n";
      for (var e in list) { report += "- ${e.name} [${e.workCenter}]\n"; }
    } else {
      var list = _employees.where((e) => e.status == 'راحة').toList();
      report = "🗓️ *تقرير الراحة الأسبوعي ($dateStr)*\n\n😴 في راحة (${list.length}):\n";
      for (var e in list) { report += "- ${e.name} [الراحة: ${e.restDays}]\n"; }
    }
    _showReportResult(report);
  }

  void _showReportResult(String text) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('معاينة التقرير'),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ!')));
            }, child: const Text('نسخ للواتساب')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _employees.where((e) => e.name.contains(_searchQuery) || e.workCenter.contains(_searchQuery)).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دليل موظفي السجن المحلي'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.indigo[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(onPressed: () => _generateReport('daily'), icon: const Icon(Icons.check), label: const Text('تقرير الحضور')),
                  ElevatedButton.icon(onPressed: () => _generateReport('weekly'), icon: const Icon(Icons.bed), label: const Text('تقرير الراحة')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(hintText: 'بحث باسم الموظف...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final emp = filtered[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: emp.status == 'في الخدمة' ? Colors.green : Colors.orange,
                        child: Text(emp.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${emp.workCenter}\nالحالة: ${emp.status}'),
                      trailing: Wrap(
                        children: [
                          if (emp.phone.isNotEmpty) IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () => launchUrl(Uri.parse('tel:${emp.phone}'))),
                          IconButton(icon: const Icon(Icons.edit, color: Colors.indigo), onPressed: () => _editEmployeeDialog(emp)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editEmployeeDialog(Employee emp) {
    final phoneController = TextEditingController(text: emp.phone);
    String tempStatus = emp.status;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تحديث: ${emp.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: tempStatus,
                  isExpanded: true,
                  items: ['في الخدمة', 'راحة', 'مهمة خفر', 'رخصة'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setDialogState(() => tempStatus = v!),
                ),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(onPressed: () {
                setState(() { emp.status = tempStatus; emp.phone = phoneController.text; });
                _saveData();
                Navigator.pop(context);
              }, child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
  }

  List<Employee> _getInitialEmployees() {
    return [
      // المجموعة 1
      Employee(id: 'EMP-1001', name: 'خلفاوي الحسين', workCenter: 'رئيس المعقل', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1002', name: 'زكرياء الكفيش', workCenter: 'نائب رئيس المعقل', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1003', name: 'البازي عبد الرحيم', workCenter: 'نائب رئيس المعقل', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1004', name: 'عبد الله بشبلا', workCenter: 'نائب رئيس المعقل', restDays: 'الخميس-الجمعة'),
      Employee(id: 'EMP-1005', name: 'علي الحراث', workCenter: 'نائب رئيس المعقل', restDays: 'الثلاثاء-الأربعاء'),
      Employee(id: 'EMP-1006', name: 'عبد الرحمان وركة', workCenter: 'التصنيف و الإيواء', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1007', name: 'سعيد الهواري', workCenter: 'ضبط سجلات باب المعقل', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1008', name: 'موسى بوري', workCenter: 'التفتيش في باب المعقل', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1009', name: 'خالد أوقاس', workCenter: 'ضبط حركة باب المعقل', restDays: 'الجمعة-السبت'),
      Employee(id: 'EMP-1010', name: 'محمد عبيد', workCenter: 'ضبط حركة باب المعقل', restDays: 'الأربعاء-الخميس'),
      Employee(id: 'EMP-1011', name: 'نور الدين جباري', workCenter: 'الخفر إلى المستشفى', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1012', name: 'عبد الحق العلمي', workCenter: 'الخفر إلى المستشفى', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1013', name: 'مهدي عزمي', workCenter: 'الخفر إلى المستشفى', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1014', name: 'بلمهدي عز الدين', workCenter: 'الخفر إلى المستشفى', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1015', name: 'خالد الغربة', workCenter: 'رئيس الحي الأول', restDays: 'الاربعاء-الخميس'),
      Employee(id: 'EMP-1016', name: 'احمد ابوزيا', workCenter: 'نائب رئيس الحي الأول', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1017', name: 'حمادي محمد', workCenter: 'الحي الأول الجناح الأول', restDays: 'الثلاثاء-الإثنين'),
      Employee(id: 'EMP-1018', name: 'ياسين اعميمي', workCenter: 'الحي الأول الجناح الأول', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1019', name: 'عبد الكريم الحنفي', workCenter: 'الحي الأول الجناح الثاني', restDays: 'الثلاثاء-الأربعاء'),
      Employee(id: 'EMP-1020', name: 'محمد حافيضي', workCenter: 'الحي الأول الجناح الثاني', restDays: 'الخميس-الجمعة'),
      Employee(id: 'EMP-1021', name: 'خالد عكوري', workCenter: 'الحي الأول الجناح الثالث', restDays: 'الثلاثاء-الأربعاء'),
      Employee(id: 'EMP-1022', name: 'التاج محمد', workCenter: 'الحي الأول الجناح الثالث', restDays: 'الخميس-الجمعة'),
      Employee(id: 'EMP-1023', name: 'ابراهيم المجدي', workCenter: 'باب الحي الأول', restDays: 'الثلاثاء-الأربعاء'),
      Employee(id: 'EMP-1024', name: 'مهدي ادراوي', workCenter: 'فسحة الحي الأول', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1025', name: 'حسن عمري', workCenter: 'رئيس الحي الثاني', restDays: 'الثلاثاء-الإثنين'),
      Employee(id: 'EMP-1026', name: 'مهدي بنعشي', workCenter: 'نائب رئيس الحي الثاني', restDays: 'الأربعاء-الخميس'),
      Employee(id: 'EMP-1027', name: 'حسن بنخديجة', workCenter: 'الجناح الأول الحي الثاني', restDays: 'الأربعاء-الخميس'),
      Employee(id: 'EMP-1028', name: 'ادريس ايت عيسى', workCenter: 'الجناح الأول الحي الثاني', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1029', name: 'هني عبد اللطيف', workCenter: 'الجناح الثاني الحي الثاني', restDays: 'الخميس-الجمعة'),
      Employee(id: 'EMP-1030', name: 'ياسين حافيضي', workCenter: 'الجناح الثاني الحي الثاني', restDays: 'الثلاثاء-الأربعاء'),
      Employee(id: 'EMP-1031', name: 'عبد العظيم فريد', workCenter: 'الجناح الثاني الحي الثاني', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1032', name: 'عمران اوحميدوش', workCenter: 'فسحة الحي الثاني', restDays: 'الثلاثاء-الأربعاء'),
      Employee(id: 'EMP-1033', name: 'وحمان يوسف', workCenter: 'رئيس الحي الثالث', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1034', name: 'محمد الكنطاري', workCenter: 'نائب رئيس الحي الثالث', restDays: 'الأربعاء-الخميس'),
      Employee(id: 'EMP-1035', name: 'مصعب بوعلام', workCenter: 'الحي الثالث الجناح الأول', restDays: 'الثلاثاء-الإثنين'),
      Employee(id: 'EMP-1036', name: 'عبد الرحمان العوفي', workCenter: 'الحي الثالث الجناح الأول', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1037', name: 'سيف الدين العبار', workCenter: 'الحي الثالث الجناح الثاني', restDays: 'السبت- الأحد'),
      Employee(id: 'EMP-1038', name: 'وليد كمال', workCenter: 'الحي الثالث الجناح الثاني', restDays: 'الخميس-الجمعة'),
      Employee(id: 'EMP-1039', name: 'رضى بنكايس', workCenter: 'الحي الثالث الجناح الثالث', restDays: 'الخميس-الجمعة'),
      Employee(id: 'EMP-1040', name: 'يونس حنيكيش', workCenter: 'الحي الثالث الجناح الثالث', restDays: 'السبت- الأحد'),
      // المجموعة 2
      Employee(id: 'EMP-1041', name: 'ياسين الغلوات', workCenter: 'فسحة الحي الثالث', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1042', name: 'رضى اغفار', workCenter: 'احضار السجناء الى قاعة الزيارة', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1043', name: 'حسن بكاري', workCenter: 'التفتيش في قاعة الزيارة', restDays: 'الجمعة-السبت'),
      Employee(id: 'EMP-1044', name: 'محمد مكناوي', workCenter: 'المسؤول عن قاعة الزيارة', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1045', name: 'الموتشو عبد الفتاح', workCenter: 'باب الموظفين', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1046', name: 'الحيمر محمد', workCenter: 'باب المرتفقين', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1047', name: 'عبد الحكيم دكاير', workCenter: 'الزيارة _المواعيد_', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1048', name: 'المهدي ديباني', workCenter: 'تفتيش المؤونة', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1049', name: 'رضا نادر', workCenter: 'تفتيش الزوار', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1050', name: 'عبد الرحمان تحيري', workCenter: 'باب الحي الثالث', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1051', name: 'عزيز الديبالي', workCenter: 'الحراسة في الضبط القضائي', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1052', name: 'الرحالي مصطفى', workCenter: 'رئيس الأمن الخارجي', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1053', name: 'إلهام البجاوي', workCenter: 'تنظيم الزيارة', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1054', name: 'موني المشماشي', workCenter: 'قاعة الزيارة', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1055', name: 'نادية احموش', workCenter: 'تفتيش المؤونة', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1056', name: 'حليمة الجرموني', workCenter: 'تفتيش الزائرات', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1057', name: 'سلمى الروينكو', workCenter: 'الاستقبال و التوجيه', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1058', name: 'خديجة بلمقدم', workCenter: 'تفتيش الزائرات', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1059', name: 'حكيمة القويسري', workCenter: 'قاعة الزيارة', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1060', name: 'نادية البغادي', workCenter: 'تسلم الاموال من الزوار', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1061', name: 'عبد العزيز الصديقي', workCenter: 'نائب الأمن الخارجي', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1062', name: 'بشرى العرفاوي', workCenter: 'نائبة رئيسة حي النساء', restDays: 'الخميس-الجمعة'),
      Employee(id: 'EMP-1063', name: 'يسرى الرامي', workCenter: 'رئيسة حي النساء', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1064', name: 'فاطمة حكيمي', workCenter: 'حي النساء _التكوين_', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1065', name: 'هلودي يونس', workCenter: 'باب الإيقاف', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1066', name: 'الختاني محمد', workCenter: 'المكلف بالنظافة', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1067', name: 'اسامة بلوش', workCenter: 'فواصل الحي الثالث', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1068', name: 'رضى نور الدين', workCenter: 'البرج 4', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1069', name: 'محمد امين الناصري', workCenter: 'المكلف بالمخالفات', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1070', name: 'السقاف مهدي', workCenter: 'الملتقى 1', restDays: 'الجمعة-السبت'),
      Employee(id: 'EMP-1071', name: 'شرعا محمد', workCenter: 'الحراسة في السجن القديم', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1072', name: 'رحالي عبد الحكيم', workCenter: 'الحراسة في السجن القديم', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1073', name: 'عبد الله تنباكور', workCenter: 'الحراسة في السجن القديم', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1074', name: 'الدويبية سعيد', workCenter: 'الحراسة في السجن القديم', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1075', name: 'عبد الصمد السحيمي', workCenter: 'فواصل الحي الثالث', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1076', name: 'عبد الصادق الصابر', workCenter: 'فواصل الحي الأول', restDays: 'الثلاثاء-الأربعاء'),
      Employee(id: 'EMP-1077', name: 'محمد عواج', workCenter: 'المداومة الليلية', restDays: 'حسب نظام المداومة'),
      // نظام الحراسة الليلية (الفرق 1-4)
      Employee(id: 'EMP-1078', name: 'اجبلي خالد', workCenter: 'حراسة ليلية 1', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1079', name: 'طارق العبسي', workCenter: 'حراسة ليلية 1', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1080', name: 'يونس جبور', workCenter: 'حراسة ليلية 1', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1092', name: 'عبد الواحد السوسي', workCenter: 'حراسة ليلية 2', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1093', name: 'العلاوي ادريس', workCenter: 'حراسة ليلية 2', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1102', name: 'سعيد الزنزون', workCenter: 'حراسة ليلية 3', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1103', name: 'باطش عبد الرحمان', workCenter: 'حراسة ليلية 3', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1113', name: 'الشابني محمد', workCenter: 'حراسة ليلية 4', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1114', name: 'مصطفى حيمي', workCenter: 'حراسة ليلية 4', restDays: 'حسب نظام الحراسة'),
      Employee(id: 'EMP-1126', name: 'محمد السامري', workCenter: 'باب الرسم', restDays: 'السبت-الأحد'),
      Employee(id: 'EMP-1134', name: 'عبد الله مساعد', workCenter: 'رخصة مرضية', restDays: 'بدون'),
    ];
  }
}
