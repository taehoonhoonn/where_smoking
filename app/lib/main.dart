import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js' as js;
import 'map_screen.dart';
import 'admin_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '흡연구역 찾기',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _TabConfig {
  const _TabConfig({required this.screen, required this.navItem});

  final Widget screen;
  final BottomNavigationBarItem navItem;
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver {
  static const int _baseTabCount = 2;
  static const int _mapTabIndex = 0;

  int _currentIndex = _mapTabIndex;
  bool _hasAdminAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _hasAdminAccess = _readAdminToken();

    js.context['flutterRefreshAdminTabs'] = js.allowInterop(() {
      if (!mounted) {
        return;
      }
      _evaluateAdminAccess();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _evaluateAdminAccess();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _evaluateAdminAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    js.context['flutterRefreshAdminTabs'] = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _evaluateAdminAccess();
    }
  }

  bool _readAdminToken() {
    try {
      if (js.context.hasProperty('ADMIN_ACCESS_TOKEN')) {
        final tokenValue = js.context['ADMIN_ACCESS_TOKEN'];
        return tokenValue is String && tokenValue.trim().isNotEmpty;
      }
    } catch (_) {
      // ignore and fall through to false
    }
    return false;
  }

  void _evaluateAdminAccess() {
    final hasAdmin = _readAdminToken();

    if (hasAdmin == _hasAdminAccess) {
      return;
    }

    if (!mounted) {
      _hasAdminAccess = hasAdmin;
      if (!_hasAdminAccess && _currentIndex >= _baseTabCount) {
        _currentIndex = _mapTabIndex;
      }
      return;
    }

    setState(() {
      _hasAdminAccess = hasAdmin;
      if (!_hasAdminAccess && _currentIndex >= _baseTabCount) {
        _currentIndex = _mapTabIndex;
      }
    });
  }

  List<_TabConfig> get _tabConfigs {
    final tabs = <_TabConfig>[
      const _TabConfig(
        screen: MapScreen(),
        navItem: BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: '지도',
        ),
      ),
      const _TabConfig(
        screen: SmokingAreaListScreen(),
        navItem: BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: '흡연구역',
        ),
      ),
    ];

    if (_hasAdminAccess) {
      tabs.addAll(const [
        _TabConfig(
          screen: AdminScreen(),
          navItem: BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: '관리자',
          ),
        ),
        _TabConfig(
          screen: ApiTestScreen(),
          navItem: BottomNavigationBarItem(
            icon: Icon(Icons.api),
            label: 'API 테스트',
          ),
        ),
      ]);
    }

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabConfigs;
    final visibleIndex = _currentIndex < tabs.length ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: visibleIndex,
        children: tabs.map((tab) => tab.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: visibleIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: tabs.map((tab) => tab.navItem).toList(),
      ),
    );
  }
}

class SmokingAreaListScreen extends StatefulWidget {
  const SmokingAreaListScreen({super.key});

  @override
  State<SmokingAreaListScreen> createState() => _SmokingAreaListScreenState();
}

class _SmokingAreaListScreenState extends State<SmokingAreaListScreen> {
  final String _baseUrl = 'https://wheresmoking-911109485093.asia-northeast3.run.app/api/v1';
  List<dynamic> _smokingAreas = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSmokingAreas();
  }

  Future<void> _loadSmokingAreas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/smoking-areas'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _smokingAreas = (data['smoking_areas'] as List<dynamic>).map((
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

  List<dynamic> get _filteredAreas {
    if (_searchQuery.isEmpty) return _smokingAreas;
    return _smokingAreas
        .where(
          (area) =>
              area['address'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              area['detail'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  // 현재 위치 기반 주변 검색
  void _searchNearbyAreas() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('현재 위치를 확인하는 중...')));

    // Geolocation API를 사용하여 현재 위치 획득
    js.context.callMethod('eval', [
      '''
      if ('geolocation' in navigator) {
        navigator.geolocation.getCurrentPosition(
          function(position) {
            var lat = position.coords.latitude;
            var lng = position.coords.longitude;

            console.log('주변 검색 - 현재 위치:', lat, lng);

            // Flutter에 위치 정보 전달
            if (window.onNearbySearchSuccess) {
              window.onNearbySearchSuccess(lat, lng);
            }
          },
          function(error) {
            console.error('위치 획득 실패:', error);
            var errorMsg = '';
            switch(error.code) {
              case error.PERMISSION_DENIED:
                errorMsg = '위치 접근 권한이 거부되었습니다. 브라우저 설정에서 위치 권한을 허용해주세요.';
                break;
              case error.POSITION_UNAVAILABLE:
                errorMsg = '위치 정보를 사용할 수 없습니다.';
                break;
              case error.TIMEOUT:
                errorMsg = '위치 요청 시간이 초과되었습니다.';
                break;
              default:
                errorMsg = '위치 확인 중 오류가 발생했습니다.';
                break;
            }

            if (window.onNearbySearchError) {
              window.onNearbySearchError(errorMsg);
            }
          },
          {
            enableHighAccuracy: true,
            timeout: 15000,
            maximumAge: 300000
          }
        );
      } else {
        if (window.onNearbySearchError) {
          window.onNearbySearchError('이 브라우저는 위치 서비스를 지원하지 않습니다.');
        }
      }
    ''',
    ]);

    // JavaScript 콜백 함수 등록
    js.context['onNearbySearchSuccess'] = js.allowInterop((
      double lat,
      double lng,
    ) {
      _fetchNearbyAreas(lat, lng);
    });

    js.context['onNearbySearchError'] = js.allowInterop((String errorMessage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('위치 확인 실패: $errorMessage')));
    });
  }

  // 주변 흡연구역 API 호출 및 결과 표시
  Future<void> _fetchNearbyAreas(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/smoking-areas/nearby?lat=$lat&lng=$lng&radius=2000&limit=20',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final nearbyAreas = data['smoking_areas'] as List;
          final count = data['count'];

          setState(() {
            _smokingAreas = nearbyAreas;
            _searchQuery = ''; // 검색어 초기화
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('현재 위치 주변 ${count}개의 흡연구역을 찾았습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(data['error'] ?? '주변 검색 실패');
        }
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주변 검색 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('흡연구역 찾기'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '주소나 장소명으로 검색...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSmokingAreas,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredAreas.length,
                itemBuilder: (context, index) {
                  final area = _filteredAreas[index];
                  final bool isCitizen = area['category'] == '시민제보';
                  final int reportCount = area['report_count'] is int
                      ? area['report_count'] as int
                      : int.tryParse('${area['report_count'] ?? 0}') ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isCitizen
                              ? const Color(0xFFFFF7D6)
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(
                          Icons.smoking_rooms,
                          color: isCitizen
                              ? const Color(0xFFF59E0B)
                              : Colors.blue,
                        ),
                      ),
                      title: Text(
                        area['address'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            area['detail'] ?? '상세 정보 없음',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCitizen
                                      ? const Color(0xFFF59E0B)
                                      : Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  area['category'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (reportCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '신고 $reportCount회',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              Text(
                                area['postal_code'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.directions),
                        onPressed: () {
                          // 길찾기 기능 (나중에 구현)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('길찾기 기능은 추후 구현 예정입니다.'),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _searchNearbyAreas,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.my_location),
        label: const Text('내 주변 찾기'),
      ),
    );
  }
}

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _output = '';
  bool _isLoading = false;
  final String _baseUrl = 'https://wheresmoking-911109485093.asia-northeast3.run.app/api/v1';

  void _log(String message) {
    setState(() {
      _output += '$message\n';
    });
  }

  void _clearLog() {
    setState(() {
      _output = '';
    });
  }

  Future<void> _testHealthCheck() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _log('🔍 헬스체크 테스트 시작...');
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _log('✅ 헬스체크 성공: ${data['status']}');
        _log('📊 응답 시간: ${data['response_time']}ms');
        _log('💾 메모리 사용량: ${data['memory']['used']}MB');
      } else {
        _log('❌ 헬스체크 실패: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ 헬스체크 실패: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testGetAllAreas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _log('🔍 전체 흡연구역 조회 테스트 시작...');
      final response = await http.get(
        Uri.parse('$_baseUrl/smoking-areas?limit=5'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _log(
            '✅ 전체 조회 성공: ${data['count']}개 중 ${data['smoking_areas'].length}개 조회',
          );
          for (var area in data['smoking_areas'].take(3)) {
            _log('  📍 ${area['category']} - ${area['address']}');
          }
        } else {
          _log('❌ 전체 조회 실패: ${data['error']}');
        }
      } else {
        _log('❌ 전체 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ 전체 조회 실패: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testNearbySearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _log('🔍 주변 검색 테스트 시작 (서울역 주변)...');
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/smoking-areas/nearby?lat=37.5547&lng=126.9707&radius=2000&limit=5',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _log('✅ 주변 검색 성공: ${data['smoking_areas'].length}개 발견');
          for (var area in data['smoking_areas']) {
            _log('  📍 ${area['category']} - ${area['address']}');
            if (area['distance_meters'] != null) {
              _log('    거리: ${area['distance_meters'].round()}m');
            }
          }
        } else {
          _log('❌ 주변 검색 실패: ${data['error']}');
        }
      } else {
        _log('❌ 주변 검색 실패: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ 주변 검색 실패: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _log('🔍 통계 조회 테스트 시작...');
      final response = await http.get(
        Uri.parse('$_baseUrl/smoking-areas/statistics'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final stats = data['statistics'];
          _log('✅ 통계 조회 성공');
          _log('  📊 총 흡연구역: ${stats['total_areas']}개');
          _log('  📈 카테고리별:');
          for (var category in stats['by_category']) {
            _log('    - ${category['category']}: ${category['count']}개');
          }
        } else {
          _log('❌ 통계 조회 실패: ${data['error']}');
        }
      } else {
        _log('❌ 통계 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ 통계 조회 실패: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('흡연구역 API 테스트'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'API 서버 연결 테스트',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testHealthCheck,
                      child: const Text('헬스체크'),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testGetAllAreas,
                      child: const Text('전체 조회'),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testNearbySearch,
                      child: const Text('주변 검색'),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testStatistics,
                      child: const Text('통계'),
                    ),
                    ElevatedButton(
                      onPressed: _clearLog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('로그 클리어'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '테스트 결과',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(width: 16),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _output.isEmpty ? '테스트 버튼을 눌러보세요.' : _output,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
