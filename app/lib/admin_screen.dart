import 'dart:convert';
import 'dart:js' as js;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    this.onNavigateToLocation,
  });

  final void Function(double latitude, double longitude, int? locationId)? onNavigateToLocation;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final String _baseUrl = getApiBaseUrl();
  List<dynamic> _pendingAreas = [];
  List<dynamic> _reportedAreas = [];
  bool _isLoading = false;
  String? _adminToken;
  TabController? _tabController;

  bool get _hasAdminAccess =>
      _adminToken != null && _adminToken!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminToken();
    _loadPendingAreas();
    _loadReportedAreas();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _loadAdminToken() {
    try {
      if (js.context.hasProperty('ADMIN_ACCESS_TOKEN')) {
        final tokenValue = js.context['ADMIN_ACCESS_TOKEN'];
        if (tokenValue is String && tokenValue.trim().isNotEmpty) {
          _adminToken = tokenValue.trim();
          return;
        }
      }
      _adminToken = null;
    } catch (error) {
      _adminToken = null;
    }
  }

  Future<void> _loadPendingAreas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final headers = {
        'Content-Type': 'application/json',
        if (_hasAdminAccess) 'X-Admin-Token': _adminToken!,
      };

      final response = await http.get(
        Uri.parse('$_baseUrl/smoking-areas/pending'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _pendingAreas = (data['pending_areas'] as List<dynamic>).map((
              area,
            ) {
              if (area is Map<String, dynamic>) {
                return {...area, 'report_count': area['report_count'] ?? 0};
              }
              return area;
            }).toList();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('데이터 로드 실패: $e')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadReportedAreas() async {
    if (!_hasAdminAccess) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/smoking-areas/reported'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Admin-Token': _adminToken!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _reportedAreas = (data['reported_areas'] as List).map((area) {
              return {
                ...area,
                'coordinates': {
                  'latitude': area['coordinates']['latitude'],
                  'longitude': area['coordinates']['longitude'],
                }
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('신고된 장소 로드 실패: $e')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _approveArea(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/smoking-areas/$id/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (_hasAdminAccess) 'X-Admin-Token': _adminToken!,
        },
        body: '{}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('흡연구역이 승인되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPendingAreas(); // 목록 새로고침
        }
      } else {
        throw Exception('승인 실패: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('승인 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectArea(int id, String? reason) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/smoking-areas/$id/reject'),
        headers: {
          'Content-Type': 'application/json',
          if (_hasAdminAccess) 'X-Admin-Token': _adminToken!,
        },
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('흡연구역 신청이 거부되었습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadPendingAreas(); // 목록 새로고침
        }
      } else {
        throw Exception('거부 실패: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('거부 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRejectDialog(int id, String address) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('신청 거부'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('다음 신청을 거부하시겠습니까?\n\n$address'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '거부 사유 (선택사항)',
                  border: OutlineInputBorder(),
                  hintText: '거부 사유를 입력하세요...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rejectArea(
                  id,
                  reasonController.text.isEmpty ? null : reasonController.text,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('거부', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 페이지'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: '대기중'),
            Tab(icon: Icon(Icons.report_problem), text: '신고된'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadPendingAreas();
              _loadReportedAreas();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 첫 번째 탭: 대기 중인 신청
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '승인 대기 중인 흡연구역',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '총 ${_pendingAreas.length}개의 신청이 대기 중입니다.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
          if (!_hasAdminAccess)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
              ),
              child: const Text(
                'ADMIN_ACCESS_TOKEN이 설정되어 있지 않습니다. 서버에서 토큰 검증을 활성화한 경우 관리자 요청이 거부될 수 있습니다.',
                style: TextStyle(fontSize: 13, color: Colors.orange),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pendingAreas.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text('승인 대기 중인 신청이 없습니다.'),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPendingAreas,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _pendingAreas.length,
                      itemBuilder: (context, index) {
                        final area = _pendingAreas[index];
                        final String category =
                            (area['category'] ?? '미분류') as String;
                        final Color categoryColor = category == '시민제보'
                            ? Colors.deepOrange
                            : Colors.teal;
                        final int reportCount = area['report_count'] is int
                            ? area['report_count'] as int
                            : int.tryParse('${area['report_count'] ?? 0}') ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'PENDING',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: categoryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        category,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  area['address'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (area['detail'] != null) ...[
                                  Text(
                                    area['detail'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  '좌표: ${area['coordinates']['latitude']}, ${area['coordinates']['longitude']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '허위 신고: $reportCount회',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: reportCount > 0
                                        ? Colors.redAccent
                                        : Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '신청일: ${DateTime.parse(area['created_at']).toLocal().toString().substring(0, 16)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _showRejectDialog(
                                        area['id'],
                                        area['address'],
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('거부'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _approveArea(area['id']),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('승인'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
            ],
          ),
          // 두 번째 탭: 신고된 장소
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '허위 신고된 흡연구역',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '총 ${_reportedAreas.length}개의 장소에 신고가 접수되었습니다.',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (!_hasAdminAccess)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
                  ),
                  child: const Text(
                    'ADMIN_ACCESS_TOKEN이 설정되어 있지 않습니다.',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _reportedAreas.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified, size: 64, color: Colors.green),
                            SizedBox(height: 16),
                            Text('신고된 장소가 없습니다.'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reportedAreas.length,
                        itemBuilder: (context, index) {
                          final area = _reportedAreas[index];
                          final reportCount = area['report_count'] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '신고 $reportCount회',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: area['category'] == '시민제보'
                                              ? Colors.orange.shade100
                                              : Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          area['category'] ?? '',
                                          style: TextStyle(
                                            color: area['category'] == '시민제보'
                                                ? Colors.orange.shade800
                                                : Colors.blue.shade800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    area['address'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (area['detail'] != null) ...[
                                    Text(
                                      area['detail'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    '좌표: ${area['coordinates']['latitude']}, ${area['coordinates']['longitude']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '최종 신고: ${DateTime.parse(area['updated_at']).toLocal().toString().substring(0, 16)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          // 지도에서 보기 기능 구현
                                          if (widget.onNavigateToLocation != null) {
                                            final coordinates = area['coordinates'];
                                            if (coordinates != null &&
                                                coordinates['latitude'] != null &&
                                                coordinates['longitude'] != null) {

                                              final lat = coordinates['latitude'].toDouble();
                                              final lng = coordinates['longitude'].toDouble();
                                              final locationId = area['id'];

                                              print('지도로 이동 요청: $lat, $lng (ID: $locationId)');

                                              widget.onNavigateToLocation!(lat, lng, locationId);

                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('지도 탭으로 이동합니다 (${area['address'] ?? '위치 정보 없음'})'),
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('좌표 정보를 찾을 수 없습니다.')),
                                              );
                                            }
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('지도 네비게이션 기능이 사용할 수 없습니다.')),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.map, size: 16),
                                        label: const Text('지도에서 보기'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
