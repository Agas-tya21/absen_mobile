// lib/camera_page.dart

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'home_page.dart';
import 'login_page.dart'; 

const String apiUrl = "http://192.168.18.9:8050"; 

class CameraPage extends StatefulWidget {
  final CameraDescription camera;
  final String aksiId;
  final String statusId;
  final String? keterangan;

  const CameraPage({
    super.key,
    required this.camera,
    required this.aksiId,
    required this.statusId,
    this.keterangan,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndPost() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (!_controller.value.isInitialized) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Kamera tidak terinisialisasi.')),
          );
        }
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin lokasi ditolak.')),
            );
          }
          Navigator.of(context).pop(false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak secara permanen, tidak dapat melanjutkan.')),
          );
        }
        Navigator.of(context).pop(false);
        return;
      }
      
      final image = await _controller.takePicture();
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      final prefs = await SharedPreferences.getInstance();
      final userNik = prefs.getString('userNik');

      // DEBUG: Log NIK pengguna
      print('User NIK from SharedPreferences: $userNik');

      if (userNik == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
        Navigator.of(context).pop(false);
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/api/transaksis'),
      );
      
      // DEBUG: Log koordinat GPS
      print('Current position: ${position.latitude}, ${position.longitude}');

      // Tambahkan file foto
      request.files.add(
        await http.MultipartFile.fromPath(
          'fotobukti', 
          image.path,
        ),
      );

      // Tambahkan data JSON dari parameter widget
      Map<String, dynamic> transaksiData = {
        "user": {"nik": userNik},
        "aksi": {"idaksi": widget.aksiId}, 
        "keterangan": widget.keterangan ?? "",
        "waktutransaksi": DateTime.now().toIso8601String(),
        "status": {"idstatus": widget.statusId}, 
        "koordinat": "${position.latitude}, ${position.longitude}"
      };

      // DEBUG: Log data JSON yang akan dikirim
      print('Sending transaction data: ${jsonEncode(transaksiData)}');
      
      request.fields['transaksi'] = jsonEncode(transaksiData);

      var response = await request.send();

      // DEBUG: Log status code respons
      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Absensi ${widget.keterangan ?? "Masuk/Pulang"} berhasil!')),
          );
          Navigator.pop(context, true); // Tutup CameraPage dan kirim sinyal berhasil
        }
      } else {
        if (mounted) {
          final responseBody = await response.stream.bytesToString();
          // DEBUG: Log body respons jika ada error
          print('Response body on error: $responseBody');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Absensi gagal: ${response.statusCode} - $responseBody')),
          );
          Navigator.pop(context, false); // Tutup CameraPage
        }
      }
    } catch (e) {
      // DEBUG: Log error yang ditangkap
      print('Caught an error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
        Navigator.pop(context, false);
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ambil Foto Absensi')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                Center(
                  child: Container(
                    width: 250,
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing ? null : _takePictureAndPost,
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}