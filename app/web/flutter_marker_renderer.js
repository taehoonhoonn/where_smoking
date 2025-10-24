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

        if (data.category === '시민제보' && citizenMarkerSvg) {
          markerOptions.icon = {
            content: citizenMarkerSvg,
            anchor: new naver.maps.Point(14, 40)
          };
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
})();
