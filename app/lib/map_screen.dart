import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final String _baseUrl = 'http://localhost:3000/api/v1';
  bool _isLoading = false;
  String _statusMessage = '지도를 로드하는 중...';
  List<dynamic> _smokingAreas = [];
  bool _isDialogShowing = false;
  int? _currentViewId;
  bool _wasInBackground = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerMapWidget();
    _loadSmokingAreas();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('앱 상태 변화: $state');

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wasInBackground = true;
      print('지도 탭이 백그라운드로 이동');
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      print('지도 탭이 포그라운드로 복귀, 마커 재생성 필요');
      // 지도가 이미 로드되어 있고 데이터가 있으면 마커 재생성
      if (_currentViewId != null && _smokingAreas.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            print('앱 복귀 후 마커 재생성 실행: ${_smokingAreas.length}개');
            _addMarkersToMap(_currentViewId!);
          }
        });
      }
    }
  }

  void _registerMapWidget() {
    // HTML 요소를 위한 고유 뷰 타입 등록
    ui.platformViewRegistry.registerViewFactory(
      'naver-map',
      (int viewId) {
        final mapContainer = html.DivElement()
          ..id = 'naver-map-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..style.backgroundColor = '#f0f0f0';

        // 디버깅을 위한 로그
        print('지도 컨테이너 생성: naver-map-$viewId');

        // 지도 초기화를 위한 지연 실행 (더 긴 지연으로 변경)
        Future.delayed(const Duration(milliseconds: 500), () {
          print('지도 초기화 시작: $viewId');
          _createNaverMap(viewId);
        });

        return mapContainer;
      },
    );
  }

  void _createNaverMap(int viewId) {
    final containerId = 'naver-map-$viewId';
    print('네이버 지도 생성 시도: $containerId');

    js.context.callMethod('eval', ['''
      function initNaverMap_$viewId() {
        console.log('지도 초기화 함수 실행:', '$containerId');

        // DOM 요소 존재 확인
        var container = document.getElementById('$containerId');
        if (!container) {
          if (!window.__naverMapInitRetries) {
            window.__naverMapInitRetries = {};
          }

          if (!window.__naverMapInitRetries[$viewId]) {
            window.__naverMapInitRetries[$viewId] = 0;
          }

          window.__naverMapInitRetries[$viewId]++;

          if (window.__naverMapInitRetries[$viewId] <= 2) {
            console.warn('지도 컨테이너를 찾을 수 없습니다:', '$containerId');
          }

          // 300ms 후 재시도
          setTimeout(initNaverMap_$viewId, 300);
          return;
        }

        if (window.__naverMapInitRetries && window.__naverMapInitRetries[$viewId]) {
          console.log('지도 컨테이너 재시도 후 발견:', '$containerId', '시도 횟수:', window.__naverMapInitRetries[$viewId]);
          delete window.__naverMapInitRetries[$viewId];
        }

        console.log('지도 컨테이너 발견:', container);

        if (typeof naver !== 'undefined' && naver.maps) {
          try {
            // 지도 옵션 설정
            var mapOptions = {
              center: new naver.maps.LatLng(37.5666805, 126.9784147), // 서울 시청
              zoom: 12,
              mapTypeControl: true,
              mapTypeControlOptions: {
                style: naver.maps.MapTypeControlStyle.BUTTON,
                position: naver.maps.Position.TOP_RIGHT
              },
              zoomControl: true,
              zoomControlOptions: {
                style: naver.maps.ZoomControlStyle.SMALL,
                position: naver.maps.Position.TOP_LEFT
              },
              scaleControl: false,
              logoControl: false,
              mapDataControl: false
            };

            console.log('지도 생성 중...', '$containerId');

            // 지도 생성
            window.naverMap_$viewId = new naver.maps.Map('$containerId', mapOptions);
            window.naverMapMarkers_$viewId = [];

            console.log('네이버 지도 로드 완료 (viewId: $viewId)');

            // 지도 클릭 시 정보창 닫기
            naver.maps.Event.addListener(window.naverMap_$viewId, 'click', function(e) {
              console.log('지도 클릭: 정보창 닫기');

              // 다이얼로그가 열려있으면 클릭 무시
              if (window.isLocationDialogShowing) {
                console.log('지도 클릭 무시: 다이얼로그 표시 중');
                return;
              }

              // 모든 정보창 닫기
              if (window.naverMapInfoWindows_$viewId) {
                window.naverMapInfoWindows_$viewId.forEach(function(infoWindow) {
                  infoWindow.close();
                });
              }
            });

            // 길게 누르기 이벤트 리스너 추가 (모바일용)
            var longPressTimer = null;
            var longPressStartPos = null;
            var isLongPress = false;
            var longPressExecuted = false;

            // 전역 중복 방지 플래그 및 디바운싱
            if (typeof window.isLocationDialogShowing === 'undefined') {
              window.isLocationDialogShowing = false;
            }
            if (typeof window.lastLongPressTime === 'undefined') {
              window.lastLongPressTime = 0;
            }

            // 터치/마우스 시작
            naver.maps.Event.addListener(window.naverMap_$viewId, 'mousedown', function(e) {
              // 다이얼로그가 이미 열려있으면 길게 누르기 무시
              if (window.isLocationDialogShowing) {
                console.log('길게 누르기 시작 무시: 이미 다이얼로그 표시 중');
                return;
              }

              isLongPress = false;
              longPressExecuted = false;
              longPressStartPos = e.coord;

              longPressTimer = setTimeout(function() {
                if (!longPressExecuted) {
                  var currentTime = Date.now();

                  // 중복 방지 확인
                  if (window.isLocationDialogShowing) {
                    console.log('길게 누르기 무시: 이미 다이얼로그 표시 중');
                    return;
                  }

                  // 시간 기반 디바운싱 (마지막 길게 누르기로부터 2초 이내는 무시)
                  if (currentTime - window.lastLongPressTime < 2000) {
                    console.log('길게 누르기 무시: 너무 빠른 연속 클릭 (디바운싱)');
                    return;
                  }

                  isLongPress = true;
                  longPressExecuted = true;
                  window.isLocationDialogShowing = true;
                  window.lastLongPressTime = currentTime;
                  console.log('길게 누르기 감지:', e.coord.lat(), e.coord.lng());

                  // Flutter로 길게 누르기 좌표 전달
                  if (window.flutter_map_longpress) {
                    window.flutter_map_longpress($viewId, e.coord.lat(), e.coord.lng());
                  }
                }
              }, 500); // 500ms 길게 누르기
            });

            // 터치/마우스 이동 (드래그 시 길게 누르기 취소)
            naver.maps.Event.addListener(window.naverMap_$viewId, 'mousemove', function(e) {
              if (longPressTimer && longPressStartPos) {
                var distance = Math.abs(e.coord.lat() - longPressStartPos.lat()) +
                              Math.abs(e.coord.lng() - longPressStartPos.lng());

                // 좌표가 너무 많이 이동하면 길게 누르기 취소
                if (distance > 0.0001) {
                  clearTimeout(longPressTimer);
                  longPressTimer = null;
                }
              }
            });

            // 터치/마우스 끝
            naver.maps.Event.addListener(window.naverMap_$viewId, 'mouseup', function(e) {
              if (longPressTimer) {
                clearTimeout(longPressTimer);
                longPressTimer = null;
              }
              // 잠시 후 플래그 리셋 (다음 길게 누르기를 위해)
              setTimeout(function() {
                longPressExecuted = false;
              }, 100);
            });

            // Flutter로 지도 로드 완료 알림 (viewId별 고유 콜백 + 전역 콜백)
            setTimeout(function() {
              console.log('Flutter 콜백 실행 시도 (viewId: $viewId)');

              // viewId별 고유 콜백 먼저 시도
              var specificCallback = window['flutter_naver_map_loaded_$viewId'];
              if (specificCallback) {
                specificCallback($viewId);
                console.log('viewId별 콜백 실행 완료 (viewId: $viewId)');
              }

              // 전역 콜백도 실행
              if (window.flutter_naver_map_loaded) {
                window.flutter_naver_map_loaded($viewId);
                console.log('전역 콜백 실행 완료 (viewId: $viewId)');
              }

              if (!specificCallback && !window.flutter_naver_map_loaded) {
                console.error('Flutter 콜백 함수를 찾을 수 없습니다');
              }
            }, 100);
          } catch (error) {
            console.error('지도 생성 중 오류:', error);
            // 1초 후 재시도
            setTimeout(initNaverMap_$viewId, 1000);
          }
        } else {
          console.error('네이버 지도 API가 로드되지 않았습니다.');
          // 1초 후 재시도
          setTimeout(initNaverMap_$viewId, 1000);
        }
      }

      // 초기화 함수 실행
      initNaverMap_$viewId();
    ''']);

    // Flutter 콜백 함수 등록 (viewId별 고유 콜백)
    js.context['flutter_naver_map_loaded_$viewId'] = js.allowInterop((int loadedViewId) {
      print('지도 로드 완료 콜백: $loadedViewId (등록된 viewId: $viewId)');
      if (mounted && loadedViewId == viewId) {
        _currentViewId = loadedViewId;
        setState(() {
          _statusMessage = '지도 로드 완료. 흡연구역을 표시하는 중...';
        });

        // 데이터가 이미 로드되어 있으면 즉시 마커 추가
        if (_smokingAreas.isNotEmpty) {
          print('기존 데이터로 마커 추가: ${_smokingAreas.length}개');
          _addMarkersToMap(loadedViewId);
        } else {
          print('데이터 로딩 후 마커 추가 예정');
          // 데이터 로딩이 완료되면 마커가 추가됨
        }
      }
    });

    // 전역 콜백도 유지 (fallback)
    js.context['flutter_naver_map_loaded'] = js.allowInterop((int loadedViewId) {
      print('전역 지도 로드 완료 콜백: $loadedViewId');
      if (mounted) {
        _currentViewId = loadedViewId;
        if (_smokingAreas.isNotEmpty) {
          _addMarkersToMap(loadedViewId);
        }
      }
    });

    // 우클릭 콜백 함수 제거됨 (모바일 앱에서는 길게 누르기만 사용)

    // 길게 누르기 콜백 함수 등록 (전역적으로 모든 viewId 처리)
    js.context['flutter_map_longpress'] = js.allowInterop((int clickedViewId, double lat, double lng) {
      print('길게 누르기 콜백: $clickedViewId, $lat, $lng');
      if (mounted) {
        _showAddLocationDialog(lat, lng);
      }
    });
  }

  Future<void> _loadSmokingAreas() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _statusMessage = '흡연구역 데이터를 불러오는 중...';
      });
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/smoking-areas'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _smokingAreas = data['smoking_areas'];
              _statusMessage = '${_smokingAreas.length}개의 흡연구역을 찾았습니다.';
            });

            // 데이터 로딩 완료 후 현재 지도에 마커 추가
            if (_currentViewId != null) {
              print('데이터 로딩 완료, 현재 지도에 마커 추가: viewId $_currentViewId');
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  _addMarkersToMap(_currentViewId!);
                }
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '데이터 로드 실패: $e';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addMarkersToMap(int viewId) {
    if (_smokingAreas.isEmpty) return;

    final mapVar = 'naverMap_$viewId';
    final markersVar = 'naverMapMarkers_$viewId';

    print('마커 추가 시작: ${_smokingAreas.length}개');

    // 기존 마커 제거
    js.context.callMethod('eval', ['''
      console.log('기존 마커 제거 시작');
      if (window.$markersVar && window.$markersVar.length > 0) {
        window.$markersVar.forEach(function(marker) {
          marker.setMap(null);
        });
        window.$markersVar = [];
        console.log('기존 마커 제거 완료');
      }
      if (!window.$markersVar) {
        window.$markersVar = [];
      }

      // InfoWindow 배열도 초기화
      if (!window.naverMapInfoWindows_$viewId) {
        window.naverMapInfoWindows_$viewId = [];
      }
    ''']);

    // 모든 마커를 한 번에 생성
    for (int i = 0; i < _smokingAreas.length; i++) {
      final area = _smokingAreas[i];
      final lat = area['coordinates']['latitude'];
      final lng = area['coordinates']['longitude'];
      final address = area['address'];
      final category = area['category'];
      final detail = area['detail'] ?? '상세 정보 없음';

      // JavaScript 문자열에서 따옴표 처리
      final safeAddress = address.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final safeCategory = category.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final safeDetail = detail.replaceAll("'", "\\'").replaceAll('"', '\\"');

      js.context.callMethod('eval', ['''
        if (window.$mapVar) {
          try {
            // 마커 생성
            var marker_$i = new naver.maps.Marker({
              position: new naver.maps.LatLng($lat, $lng),
              map: window.$mapVar
            });

            window.$markersVar.push(marker_$i);

            // 각 마커마다 고유한 정보창 생성
            var infoWindow_$i = new naver.maps.InfoWindow({
              content: '<div style="padding: 15px; max-width: 300px;">' +
                       '<h4 style="margin: 0 0 10px 0; color: #333;">$safeCategory</h4>' +
                       '<p style="margin: 0 0 8px 0; color: #666; font-size: 14px;"><strong>주소:</strong> $safeAddress</p>' +
                       '<p style="margin: 0; color: #666; font-size: 14px;"><strong>상세:</strong> $safeDetail</p>' +
                       '</div>'
            });

            // InfoWindow 배열에 저장
            window.naverMapInfoWindows_$viewId.push(infoWindow_$i);

            // 클릭 이벤트 추가 (클로저로 현재 InfoWindow 캡처)
            naver.maps.Event.addListener(marker_$i, 'click', (function(currentInfoWindow) {
              return function() {
                // 다른 모든 InfoWindow 닫기
                window.naverMapInfoWindows_$viewId.forEach(function(iw) {
                  if (iw.getMap()) {
                    iw.close();
                  }
                });

                // 현재 InfoWindow 열기
                currentInfoWindow.open(window.$mapVar, marker_$i);
                console.log('InfoWindow $i 열림:', '$safeAddress');
              };
            })(infoWindow_$i));

            console.log('마커 $i 생성 완료:', '$safeAddress');

          } catch (error) {
            console.error('마커 $i 생성 오류:', error);
          }
        }
      ''']);
    }

    // 모든 마커가 보이도록 지도 범위 조정
    js.context.callMethod('eval', ['''
      console.log('지도 범위 조정 시작, 마커 개수:', window.$markersVar.length);
      if (window.$mapVar && window.$markersVar && window.$markersVar.length > 0) {
        var bounds = new naver.maps.LatLngBounds();
        window.$markersVar.forEach(function(marker) {
          bounds.extend(marker.getPosition());
        });
        window.$mapVar.fitBounds(bounds, {top: 50, right: 50, bottom: 50, left: 50});
        console.log('지도 범위 조정 완료');
      }
    ''']);

    if (mounted) {
      setState(() {
        _statusMessage = '${_smokingAreas.length}개의 흡연구역이 지도에 표시되었습니다.';
      });
    }
  }

  Future<void> _searchNearby() async {
    // 현재 지도 중심 좌표 가져오기
    final centerInfo = js.context.callMethod('eval', ['''
      if (window.naverMap) {
        var center = window.naverMap.getCenter();
        JSON.stringify({lat: center.lat(), lng: center.lng()});
      }
    ''']);

    if (centerInfo != null) {
      final center = json.decode(centerInfo);

      if (mounted) {
        setState(() {
          _isLoading = true;
          _statusMessage = '주변 흡연구역을 검색하는 중...';
        });
      }

      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/smoking-areas/nearby?lat=${center['lat']}&lng=${center['lng']}&radius=2000&limit=20'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              setState(() {
                _statusMessage = '주변 ${data['smoking_areas'].length}개의 흡연구역을 찾았습니다.';
              });
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = '검색 실패: $e';
          });
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 마커 재생성 함수 (더 간단하고 확실한 방법)
  void _forceRefreshMarkers() {
    if (_currentViewId != null && _smokingAreas.isNotEmpty && mounted) {
      print('강제 마커 재생성 실행: ${_smokingAreas.length}개');
      _addMarkersToMap(_currentViewId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수

    return Scaffold(
      appBar: AppBar(
        title: const Text('흡연구역 지도'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSmokingAreas,
            tooltip: '데이터 새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _forceRefreshMarkers,
            tooltip: '마커 재생성',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchNearby,
            tooltip: '주변 검색',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
          // 상태 표시 바
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // 지도 영역
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  const HtmlElementView(viewType: 'naver-map'),
                  // 마커 로드 상태 표시 오버레이
                  if (_smokingAreas.isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_smokingAreas.length}개 마커 로드됨',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 하단 정보 패널
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '범례',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          '🚬',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('부분 개방형'),
                    const SizedBox(width: 24),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          '🚬',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('완전 폐쇄형'),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
        // 다이얼로그가 열릴 때 지도 클릭 방지를 위한 오버레이
        if (_isDialogShowing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Text(
                '흡연구역 등록 중...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moveToMyLocation,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location),
        tooltip: '현재 위치로 이동',
      ),
    );
  }

  void _moveToMyLocation() {
    if (mounted) {
      setState(() {
        _statusMessage = '현재 위치를 찾는 중...';
      });
    }

    // Geolocation API를 사용하여 현재 위치 획득
    js.context.callMethod('eval', ['''
      if ('geolocation' in navigator) {
        navigator.geolocation.getCurrentPosition(
          function(position) {
            var lat = position.coords.latitude;
            var lng = position.coords.longitude;
            var accuracy = position.coords.accuracy;

            console.log('현재 위치 획득 성공:', lat, lng, '정확도:', accuracy + 'm');

            // 현재 활성화된 지도 찾기
            var activeMap = null;
            for (var prop in window) {
              if (prop.startsWith('naverMap_') && window[prop]) {
                activeMap = window[prop];
                break;
              }
            }

            if (activeMap) {
              // 현재 위치로 지도 중심 이동
              var currentPosition = new naver.maps.LatLng(lat, lng);
              activeMap.setCenter(currentPosition);
              activeMap.setZoom(16); // 조금 더 확대

              // 기존 현재 위치 마커 제거
              if (window.currentLocationMarker) {
                window.currentLocationMarker.setMap(null);
              }

              // 현재 위치 마커 생성 (파란색 원형)
              window.currentLocationMarker = new naver.maps.Marker({
                position: currentPosition,
                map: activeMap,
                icon: {
                  content: '<div style="width:20px;height:20px;background:#4285F4;border:3px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3);"></div>',
                  anchor: new naver.maps.Point(10, 10)
                },
                title: '현재 위치'
              });

              console.log('현재 위치 마커 표시 완료');
            }

            // Flutter에 성공 알림
            window.flutter_inappwebview && window.flutter_inappwebview.callHandler('locationSuccess', {
              latitude: lat,
              longitude: lng,
              accuracy: accuracy
            });

            // 전역 콜백으로 Flutter에 알림
            if (window.onLocationSuccess) {
              window.onLocationSuccess(lat, lng, accuracy);
            }
          },
          function(error) {
            console.error('위치 획득 실패:', error.message);
            var errorMsg = '';
            switch(error.code) {
              case error.PERMISSION_DENIED:
                errorMsg = '위치 접근 권한이 거부되었습니다.';
                break;
              case error.POSITION_UNAVAILABLE:
                errorMsg = '위치 정보를 사용할 수 없습니다.';
                break;
              case error.TIMEOUT:
                errorMsg = '위치 요청 시간이 초과되었습니다.';
                break;
              default:
                errorMsg = '알 수 없는 오류가 발생했습니다.';
                break;
            }

            // Flutter에 오류 알림
            if (window.onLocationError) {
              window.onLocationError(errorMsg);
            }
          },
          {
            enableHighAccuracy: true,  // GPS 사용으로 높은 정확도
            timeout: 15000,           // 15초 타임아웃
            maximumAge: 300000        // 5분간 캐시된 위치 사용 가능
          }
        );
      } else {
        console.error('Geolocation API를 지원하지 않는 브라우저입니다.');
        if (window.onLocationError) {
          window.onLocationError('이 브라우저는 위치 서비스를 지원하지 않습니다.');
        }
      }
    ''']);

    // JavaScript 콜백 함수 등록
    js.context['onLocationSuccess'] = js.allowInterop((double lat, double lng, double accuracy) {
      // mounted 체크로 위젯이 여전히 트리에 있는지 확인
      if (mounted) {
        setState(() {
          _statusMessage = '현재 위치로 이동했습니다. (정확도: ${accuracy.toInt()}m)';
        });

        // 주변 흡연구역 자동 검색
        _searchNearbyAreas(lat, lng);
      }
    });

    js.context['onLocationError'] = js.allowInterop((String errorMessage) {
      // mounted 체크로 위젯이 여전히 트리에 있는지 확인
      if (mounted) {
        setState(() {
          _statusMessage = '위치 획득 실패: $errorMessage';
        });
      }
    });
  }

  // 현재 위치 기반 주변 흡연구역 검색
  Future<void> _searchNearbyAreas(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/smoking-areas/nearby?lat=$lat&lng=$lng&radius=1000&limit=10'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final nearbyCount = data['count'] ?? 0;
          // mounted 체크로 안전한 setState 호출
          if (mounted) {
            setState(() {
              _statusMessage = '현재 위치 주변 ${nearbyCount}개의 흡연구역을 찾았습니다.';
            });
          }
        }
      }
    } catch (e) {
      print('주변 검색 오류: $e');
    }
  }

  // 우클릭 시 장소 등록 다이얼로그 표시
  void _resetDialogState() {
    // 다이얼로그 상태 리셋
    _isDialogShowing = false;

    // 지도 이벤트 다시 활성화
    js.context.callMethod('eval', ['''
      // 모든 지도 컨테이너의 포인터 이벤트 활성화
      var mapContainers = document.querySelectorAll('[id^="naver-map-"]');
      mapContainers.forEach(function(container) {
        container.style.pointerEvents = 'auto';
        console.log('지도 이벤트 활성화:', container.id);
      });
    ''']);

    // JavaScript 전역 플래그도 리셋
    js.context.callMethod('eval', ['''
      window.isLocationDialogShowing = false;
      // 버튼 클릭 시 즉시 다시 길게 누르기 가능하도록 타임스탬프 조정
      window.lastLongPressTime = Date.now() - 2500; // 2.5초 전으로 설정
      console.log('다이얼로그 완전 리셋: 길게 누르기 다시 활성화');
    ''']);
  }

  void _showAddLocationDialog(double lat, double lng) async {
    // 이미 다이얼로그가 표시 중이면 무시
    if (_isDialogShowing) {
      print('다이얼로그 중복 호출 방지: 이미 표시 중');
      return;
    }

    _isDialogShowing = true;

    // 지도 이벤트 완전히 비활성화
    js.context.callMethod('eval', ['''
      // 모든 지도 컨테이너의 포인터 이벤트 비활성화
      var mapContainers = document.querySelectorAll('[id^="naver-map-"]');
      mapContainers.forEach(function(container) {
        container.style.pointerEvents = 'none';
        console.log('지도 이벤트 비활성화:', container.id);
      });
    ''']);

    // 먼저 확인 다이얼로그 표시
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('흡연구역 등록'),
          content: Text('이 위치에 새로운 흡연구역을 등록하시겠습니까?\n\n위치: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('등록하기'),
            ),
          ],
        );
      },
    );

    // 다이얼로그 상태 리셋
    _resetDialogState();

    // 사용자가 확인을 누른 경우 상세 정보 입력 폼 표시
    if (confirm == true) {
      _showLocationDetailDialog(lat, lng);
    }
  }

  // 상세 정보 입력 다이얼로그
  void _showLocationDetailDialog(double lat, double lng) {
    // 상세 다이얼로그가 열릴 때도 다이얼로그 상태 유지
    _isDialogShowing = true;

    final TextEditingController detailController = TextEditingController();
    String selectedCategory = '부분 개방형';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('흡연구역 상세 정보'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('위치 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('좌표: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'),
                    const SizedBox(height: 16),

                    const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: '부분 개방형', child: Text('부분 개방형')),
                        DropdownMenuItem(value: '완전 폐쇄형', child: Text('완전 폐쇄형')),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('상세 설명 (선택사항)', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: detailController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '이 흡연구역에 대한 추가 정보를 입력하세요...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '* 등록된 정보는 관리자 검토 후 지도에 반영됩니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetDialogState(); // 취소 시 다이얼로그 상태 리셋
                  },
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _submitNewLocation(lat, lng, selectedCategory, detailController.text);
                    Navigator.of(context).pop();
                    _resetDialogState(); // 등록 신청 시 다이얼로그 상태 리셋
                  },
                  child: const Text('등록 신청'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 새 장소 등록 API 호출
  Future<void> _submitNewLocation(double lat, double lng, String category, String detail) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _statusMessage = '새로운 흡연구역을 등록하는 중...';
      });
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/smoking-areas/pending'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': lat,
          'longitude': lng,
          'category': category,
          'detail': detail.isEmpty ? null : detail,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _statusMessage = '흡연구역 등록 신청이 완료되었습니다. 관리자 검토 후 반영됩니다.';
          });
        }

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('흡연구역 등록 신청이 완료되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('등록 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '등록 신청 중 오류가 발생했습니다: $e';
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // WidgetsBindingObserver 제거
    WidgetsBinding.instance.removeObserver(this);
    // JavaScript 콜백 함수 정리하여 메모리 리크 방지
    js.context['onLocationSuccess'] = null;
    js.context['onLocationError'] = null;
    js.context['flutter_naver_map_loaded'] = null;
    js.context['flutter_map_longpress'] = null;

    // viewId별 콜백도 정리
    if (_currentViewId != null) {
      js.context['flutter_naver_map_loaded_$_currentViewId'] = null;
    }

    super.dispose();
  }

}
