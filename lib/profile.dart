import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> moodLogs = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchMoodLogs();
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      setState(() {
        userData = doc.data();
      });
    }
  }

  Future<void> fetchMoodLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('mood_logs')
              .where('uid', isEqualTo: user.uid)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
              )
              .orderBy('timestamp')
              .get();

      setState(() {
        moodLogs =
            querySnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();
      });
    }
  }

  int getMoodValue(String mood) {
    switch (mood.toLowerCase()) {
      case 'very sad':
        return 0;
      case 'sad':
        return 1;
      case 'anxious':
        return 2;
      case 'calm':
        return 3;
      case 'happy':
        return 4;
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body:
          userData == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(20.0),
                child: ListView(
                  children: [
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildProfileItem(
                              "Username",
                              userData!['username'] ?? '',
                            ),
                            buildProfileItem("Email", userData!['email'] ?? ''),
                            buildProfileItem("Age", userData!['age'] ?? ''),
                            buildProfileItem(
                              "Gender",
                              userData!['gender'] ?? '',
                            ),
                            buildProfileItem(
                              "Reason for Joining",
                              userData!['reason'] ?? '',
                            ),
                            buildProfileItem(
                              "Mood Check-in Frequency",
                              userData!['checkInFrequency'] ?? '',
                            ),
                            buildProfileItem(
                              "Notifications Enabled",
                              userData!['notifications'] ? 'Yes' : 'No',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Mood Summary (Last 7 Days)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    moodLogs.length < 2
                        ? const Text(
                          "Not enough mood data yet. Keep tracking to see your progress!",
                        )
                        : SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: true),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      int index = value.toInt();
                                      if (index < moodLogs.length) {
                                        final date =
                                            moodLogs[index]['timestamp']
                                                .toDate();
                                        return Text(
                                          DateFormat.Md().format(date),
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      const moodScale = [
                                        '😢',
                                        '😟',
                                        '😐',
                                        '😌',
                                        '😊',
                                      ];
                                      int index = value.toInt();
                                      if (index >= 0 &&
                                          index < moodScale.length) {
                                        return Text(moodScale[index]);
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    moodLogs.length,
                                    (index) => FlSpot(
                                      index.toDouble(),
                                      getMoodValue(
                                        moodLogs[index]['mood'],
                                      ).toDouble(),
                                    ),
                                  ),
                                  isCurved: true,
                                  barWidth: 3,
                                  color: Colors.deepPurple,
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
    );
  }

  Widget buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
