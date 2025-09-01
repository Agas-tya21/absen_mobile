import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'camera_page.dart';
import 'package:camera/camera.dart';

const String apiUrl = "http://192.168.18.9:8050"; 

// Model untuk data transaksi
class Transaksi {
  final String idtransaksi;
  final String keterangan;
  final DateTime waktutransaksi;
  final String namaaksi;
  final String namastatus;

  Transaksi({
    required this.idtransaksi,
    required this.keterangan,
    required this.waktutransaksi,
    required this.namaaksi,
    required this.namastatus,
  });

  factory Transaksi.fromJson(Map<String, dynamic> json) {
    return Transaksi(
      idtransaksi: json['idtransaksi'] ?? '',
      keterangan: json['keterangan'] ?? '-',
      waktutransaksi: DateTime.parse(json['waktutransaksi']),
      namaaksi: json['aksi']['namaaksi'] ?? 'N/A',
      namastatus: json['status']['namastatus'] ?? 'N/A',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = 'Loading...';
  String _userPhotoUrl = '';
  bool _isLoading = true;
  String? _userNik;
  List<Transaksi> _transaksiList = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userNik = prefs.getString('userNik');

      if (_userNik == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
        return;
      }

      // Ambil data user
      final userResponse = await http.get(Uri.parse('$apiUrl/api/users/$_userNik'));
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        setState(() {
          _userName = userData['nama'];
          _userPhotoUrl = userData['fotoselfie'];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load user data: ${userResponse.statusCode}')),
          );
        }
      }

      // Ambil data transaksi
      final transaksiResponse = await http.get(Uri.parse('$apiUrl/api/transaksis'));
      if (transaksiResponse.statusCode == 200) {
        final List<dynamic> transaksiData = jsonDecode(transaksiResponse.body);
        final userTransactions = transaksiData
            .where((json) => json['user']['nik'] == _userNik)
            .map((json) => Transaksi.fromJson(json))
            .toList();

        setState(() {
          _transaksiList = userTransactions;
        });
      } else if (transaksiResponse.statusCode == 204) {
        setState(() {
          _transaksiList = [];
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load transactions: ${transaksiResponse.statusCode}')),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userNik');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<void> _handleAbsen({
    required String aksiId,
    required String statusId,
    String? keterangan,
  }) async {
    final cameras = await availableCameras();
    CameraDescription? frontCamera;
    
    // Cari kamera depan
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    final selectedCamera = frontCamera ?? cameras.first;
    
    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraPage(
            camera: selectedCamera,
            aksiId: aksiId,
            statusId: statusId,
            keterangan: keterangan,
          ),
        ),
      );
      if (result == true) {
        // Refresh data setelah transaksi berhasil
        _fetchUserData();
      }
    }
  }
  
  void _showIzinDialog() {
    final TextEditingController keteranganController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Keterangan Izin'),
          content: TextField(
            controller: keteranganController,
            decoration: const InputDecoration(hintText: "Masukkan alasan izin"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Lanjutkan'),
              onPressed: () {
                if (keteranganController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  _handleAbsen(
                    aksiId: "aks003",
                    statusId: "s002",
                    keterangan: keteranganController.text,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Keterangan tidak boleh kosong.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              minHeight: 100,
              maxHeight: 100,
              child: ColoredBox(
                color: const Color(0xFF19535F),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      _isLoading
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _userPhotoUrl.isNotEmpty
                                  ? NetworkImage(_userPhotoUrl)
                                  : null,
                              child: _userPhotoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 30, color: Colors.grey)
                                  : null,
                            ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (String result) {
                          if (result == 'logout') {
                            _logout();
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: Text('Logout'),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  switch(index) {
                    case 0:
                      return Card(
                        color: const Color(0xFF336C67),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: () => _handleAbsen(
                            aksiId: "aks001",
                            statusId: "s001",
                            keterangan: "Absensi masuk",
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: const Center(
                            child: Text(
                              'Masuk',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    case 1:
                      return Card(
                        color: Colors.orange,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: _showIzinDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: const Center(
                            child: Text(
                              'Izin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    case 2:
                      return Card(
                        color: Colors.red,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: () => _handleAbsen(
                            aksiId: "aks002",
                            statusId: "s001",
                            keterangan: "Absensi pulang",
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: const Center(
                            child: Text(
                              'Pulang',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    default:
                      return null;
                  }
                },
                childCount: 3, 
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Text(
                'Riwayat Transaksi',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          _isLoading
              ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
              : _transaksiList.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text('Tidak ada riwayat transaksi.', style: TextStyle(color: Colors.grey[600])),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final transaksi = _transaksiList[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                            child: Card(
                              elevation: 2,
                              child: ListTile(
                                leading: Icon(
                                  transaksi.namaaksi.toLowerCase() == 'masuk'
                                      ? Icons.login
                                      : transaksi.namaaksi.toLowerCase() == 'pulang'
                                          ? Icons.logout
                                          : Icons.pending,
                                  color: transaksi.namaaksi.toLowerCase() == 'masuk'
                                      ? Colors.green
                                      : transaksi.namaaksi.toLowerCase() == 'pulang'
                                          ? Colors.red
                                          : Colors.orange,
                                ),
                                title: Text('${transaksi.namaaksi} - ${transaksi.keterangan}'),
                                subtitle: Text('${transaksi.waktutransaksi.toLocal().toString().split('.')[0]} (${transaksi.namastatus})'),
                              ),
                            ),
                          );
                        },
                        childCount: _transaksiList.length,
                      ),
                    ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}