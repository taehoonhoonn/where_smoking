(function () {
  if (typeof window === 'undefined') {
    return;
  }

  if (window.flutterRenderSmokingMarkers) {
    return;
  }

  function fitBoundsToMarkers(map, markers) {
    if (!Array.isArray(markers) || !markers.length) {
      return;
    }

    var bounds = null;
    markers.forEach(function (marker) {
      var pos = marker.getPosition();
      if (!pos) {
        return;
      }
      if (!bounds) {
        bounds = new naver.maps.LatLngBounds(pos, pos);
      } else {
        bounds.extend(pos);
      }
    });

    if (bounds) {
      map.fitBounds(bounds, { top: 50, right: 50, bottom: 50, left: 50 });
    }
  }

  window.flutterRenderSmokingMarkers = function (config) {
    if (!config) {
      console.warn('마커 렌더링 설정이 비어 있습니다.');
      return;
    }

    var viewId = config.viewId;
    if (typeof viewId === 'undefined' || viewId === null) {
      console.warn('viewId가 없어 마커를 렌더링할 수 없습니다.');
      return;
    }

    var mapVar = 'naverMap_' + viewId;
    var markersVar = 'naverMapMarkers_' + viewId;
    var infoWindowsVar = 'naverMapInfoWindows_' + viewId;
    var clustererVar = 'naverMapClusterer_' + viewId;

    var map = window[mapVar];
    if (!map) {
      console.warn('지도 객체를 찾을 수 없어 마커 생성을 건너뜁니다.', mapVar);
      return;
    }

    var existingMarkers = window[markersVar];
    if (Array.isArray(existingMarkers)) {
      existingMarkers.forEach(function (marker) {
        try {
          marker.setMap(null);
        } catch (err) {
          console.warn('기존 마커 제거 실패:', err);
        }
      });
    }
    window[markersVar] = [];

    var infoWindows = window[infoWindowsVar];
    if (Array.isArray(infoWindows)) {
      infoWindows.forEach(function (infoWindow) {
        try {
          infoWindow.close();
        } catch (err) {
          console.warn('기존 정보창 닫기 실패:', err);
        }
      });
    }
    window[infoWindowsVar] = [];

    if (window[clustererVar]) {
      try {
        window[clustererVar].setMap(null);
      } catch (err) {
        console.warn('기존 클러스터러 해제 실패:', err);
      }
      window[clustererVar] = null;
    }

    var markerDataList = Array.isArray(config.markers) ? config.markers : [];
    if (!markerDataList.length) {
      console.log('마커 데이터가 비어 있어 렌더링을 건너뜁니다.');
      return;
    }

    var citizenMarkerSvg = config.citizenMarkerSvg || '';
    var shouldFitBounds = config.shouldFitBounds === true;

    markerDataList.forEach(function (data) {
      try {
        if (!data) {
          return;
        }

        var markerOptions = {
          position: new naver.maps.LatLng(data.lat, data.lng),
          map: map
        };

        if (data.category === '시민제보') {
          var citizenSvgContent = citizenMarkerSvg;

          // 디버깅 로그
          console.log('시민제보 마커:', {
            id: data.id,
            category: data.category,
            submitted_category: data.submitted_category,
            address: data.address
          });

          // submitted_category에 따라 색상 결정
          if (data.submitted_category === '공식 흡연장소') {
            // 진한 초록색 (#16A34A) - 배경과 테두리 모두 변경
            citizenSvgContent = citizenMarkerSvg
              .replace(/#FACC15/g, '#16A34A')  // fill 색상 변경
              .replace(/#C08900/g, '#0F7A2C'); // stroke 색상 변경 (더 진한 초록)
            console.log('공식 흡연장소 -> 초록색 적용 (배경 + 테두리)');
          } else if (data.submitted_category === '비공식 흡연장소') {
            // 노란색 (#FACC15) - 기존 색상 유지
            citizenSvgContent = citizenMarkerSvg;
            console.log('비공식 흡연장소 -> 노란색 유지');
          } else {
            // null이거나 알 수 없는 경우 기본값으로 비공식 흡연장소(노란색) 처리
            citizenSvgContent = citizenMarkerSvg;
            console.log('기본값 -> 비공식 흡연장소(노란색), submitted_category:', data.submitted_category);
          }

          if (citizenSvgContent) {
            markerOptions.icon = {
              content: citizenSvgContent,
              anchor: new naver.maps.Point(14, 40)
            };
          }
        }

        var marker = new naver.maps.Marker(markerOptions);
        marker.smokingAreaData = {
          id: data.id,
          address: data.address,
          detail: data.detail,
          category: data.category
        };

        window[markersVar].push(marker);

        var infoWindow = new naver.maps.InfoWindow({
          content: data.infoWindowContent
        });
        window[infoWindowsVar].push(infoWindow);

        naver.maps.Event.addListener(marker, 'click', (function (currentInfoWindow) {
          return function () {
            window[infoWindowsVar].forEach(function (iw) {
              try {
                if (iw.getMap()) {
                  iw.close();
                }
              } catch (err) {
                console.warn('정보창 닫기 실패:', err);
              }
            });

            currentInfoWindow.open(map, marker);
          };
        })(infoWindow));
      } catch (err) {
        console.error('마커 생성 오류:', data, err);
      }
    });

    if (shouldFitBounds) {
      fitBoundsToMarkers(map, window[markersVar]);
    }
  };

  // 중앙 핀 마커 추가 함수 (검색된 위치를 명확하게 표시)
  window.addCenterPinMarker = function(viewId, lat, lng) {
    if (typeof viewId === 'undefined' || viewId === null) {
      console.warn('viewId가 없어 중앙 핀을 추가할 수 없습니다.');
      return;
    }

    var mapVar = 'naverMap_' + viewId;
    var centerPinVar = 'centerPinMarker_' + viewId;

    var map = window[mapVar];
    if (!map) {
      console.warn('지도 객체를 찾을 수 없어 중앙 핀 생성을 건너뜁니다.');
      return;
    }

    // 기존 중앙 핀 제거
    if (window[centerPinVar]) {
      try {
        window[centerPinVar].setMap(null);
        delete window[centerPinVar];
      } catch (err) {
        console.warn('기존 중앙 핀 제거 실패:', err);
      }
    }

    // 펄싱 애니메이션을 포함한 위치 핀 SVG
    var centerPinSvg = `
      <div style="position: relative; width: 50px; height: 50px;">
        <!-- 펄싱 애니메이션 링 -->
        <style>
          @keyframes pulse {
            0% {
              transform: scale(0.8);
              opacity: 0.8;
            }
            50% {
              transform: scale(1.3);
              opacity: 0.3;
            }
            100% {
              transform: scale(0.8);
              opacity: 0.8;
            }
          }
          .pulse-ring {
            animation: pulse 2s ease-in-out infinite;
          }
        </style>

        <!-- 외부 펄싱 링 -->
        <div class="pulse-ring" style="
          position: absolute;
          width: 40px;
          height: 40px;
          border-radius: 50%;
          background-color: rgba(255, 68, 68, 0.3);
          top: 5px;
          left: 5px;
        "></div>

        <!-- 위치 핀 아이콘 -->
        <svg width="50" height="50" viewBox="0 0 50 50" xmlns="http://www.w3.org/2000/svg" style="position: absolute; top: 0; left: 0;">
          <!-- 핀 그림자 -->
          <ellipse cx="25" cy="45" rx="8" ry="3" fill="rgba(0,0,0,0.3)"/>

          <!-- 핀 본체 -->
          <path d="M 25 5 C 17 5 10 12 10 20 C 10 30 25 45 25 45 C 25 45 40 30 40 20 C 40 12 33 5 25 5 Z"
                fill="#ff4444"
                stroke="#cc0000"
                stroke-width="2"/>

          <!-- 핀 내부 원 -->
          <circle cx="25" cy="20" r="6" fill="white"/>

          <!-- 핀 내부 점 -->
          <circle cx="25" cy="20" r="3" fill="#ff4444"/>
        </svg>
      </div>
    `;

    // 중앙 핀 마커 생성
    try {
      var marker = new naver.maps.Marker({
        position: new naver.maps.LatLng(lat, lng),
        map: map,
        icon: {
          content: centerPinSvg,
          anchor: new naver.maps.Point(25, 45)  // 핀 아래쪽 끝을 기준점으로
        },
        zIndex: 999  // 검색 마커(1000)보다 약간 낮게
      });

      window[centerPinVar] = marker;
      console.log('중앙 핀 마커가 추가되었습니다:', lat, lng);
    } catch (err) {
      console.error('중앙 핀 마커 생성 오류:', err);
    }
  };

  // 중앙 핀 제거 함수
  window.removeCenterPinMarker = function(viewId) {
    if (typeof viewId === 'undefined' || viewId === null) {
      return;
    }

    var centerPinVar = 'centerPinMarker_' + viewId;

    if (window[centerPinVar]) {
      try {
        window[centerPinVar].setMap(null);
        delete window[centerPinVar];
        console.log('중앙 핀 마커가 제거되었습니다.');
      } catch (err) {
        console.warn('중앙 핀 제거 실패:', err);
      }
    }
  };

})();
