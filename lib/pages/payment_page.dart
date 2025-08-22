import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool isLoading = true;
  bool isPaid = false;
  Map<String, dynamic>? billData;
  int? studentId;
  String? token;

  @override
  void initState() {
    super.initState();
    initUser();
  }

  /// Ambil token + student_id dari SharedPreferences
  Future<void> initUser() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ sesuaikan dengan LoginPage & AuthService
    token = prefs.getString("access_token");
    studentId = int.tryParse(prefs.getString("user_id") ?? "0");

    if (studentId == null || token == null || studentId == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User tidak ditemukan, silakan login ulang")),
        );
        Navigator.pop(context);
      }
      return;
    }

    fetchBill();
  }

  /// Ambil data tagihan dari API Laravel
  Future<void> fetchBill() async {
    try {
      final url = Uri.parse("http://10.0.2.2:8000/api/bill-spp-student/$studentId");
      final response = await http.get(
        url,
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          billData = (data["data"] as List).isNotEmpty ? data["data"][0] : null;
          isPaid = billData?["status"] == "paid";
          isLoading = false;
        });
      } else {
        throw Exception("Gagal ambil data bill (${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Error fetchBill: $e");
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal ambil data: $e")),
        );
      }
    }
  }

  /// Proses pembayaran ke API Laravel
  Future<void> doPayment() async {
    if (billData == null || studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data tagihan tidak tersedia")),
      );
      return;
    }

    try {
      final url = Uri.parse("http://10.0.2.2:8000/api/payment");
      final response = await http.post(
        url,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "student_id": studentId,
          "spp_id": billData?["spp_id"],
          "total_amount": billData?["amount"],
          "method_payment": "transfer",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "paid") {
          setState(() {
            isPaid = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pembayaran berhasil ✅")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "Pembayaran gagal ❌")),
          );
        }
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err["message"] ?? "Pembayaran gagal ❌")),
        );
      }
    } catch (e) {
      debugPrint("Error doPayment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("SmartSPP"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple,
        elevation: 0,
      ),
      body: isPaid ? buildSuccessPage() : buildPaymentForm(),
    );
  }

  /// FORM Pembayaran (UI tetap sama)
  Widget buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.purple],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Pay",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple)),
              const SizedBox(height: 10),
              TextFormField(
                readOnly: true,
                initialValue: "D*** I*******",
                decoration: const InputDecoration(labelText: "Student Name"),
              ),
              TextFormField(
                readOnly: true,
                initialValue: studentId?.toString() ?? "-",
                decoration:
                    const InputDecoration(labelText: "Student ID Number"),
              ),
              TextFormField(
                readOnly: true,
                initialValue: "XII RPL 3",
                decoration: const InputDecoration(labelText: "Class"),
              ),
              TextFormField(
                readOnly: true,
                initialValue: "${billData?["month"]} / ${billData?["year"]}",
                decoration: const InputDecoration(labelText: "Date"),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      initialValue: "Rp. ${billData?["amount"]}",
                      decoration: const InputDecoration(labelText: "Nominal"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      initialValue: "Rp. 10.000",
                      decoration: const InputDecoration(labelText: "Saving"),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
              const Text("Payment",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Image.asset("assets/bca.png", width: 60),
                  Image.asset("assets/bri.png", width: 60),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Image.asset("assets/mandiri.png", width: 60),
                  Image.asset("assets/bsi.png", width: 60),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: doPayment,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12)),
                  child: const Text("Bayar Sekarang"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// HALAMAN sukses bayar (UI tetap sama)
  Widget buildSuccessPage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.purple],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("Transaksi Berhasil",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const SizedBox(height: 8),
              Text("${billData?["year"]}-${billData?["month"]}"),
              const SizedBox(height: 20),
              Text(
                "Rp. ${billData?["amount"]}",
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                },
                children: const [
                  TableRow(children: [
                    Text("Penerima"),
                    Text("SMK Taruna Bhakti")
                  ]),
                  TableRow(children: [
                    Text("Bank Penerima"),
                    Text("BSI (Bank Syariah Indonesia)")
                  ]),
                  TableRow(children: [
                    Text("Nomor Rekening"),
                    Text("6704091101939")
                  ]),
                  TableRow(children: [
                    Text("Catatan Transfer"),
                    Text("SPP Juli")
                  ]),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12)),
                child: const Text("Kembali"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
