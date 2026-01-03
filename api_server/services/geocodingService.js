const axios = require('axios');
const { debugLogger, errorLogger } = require('../config/logger');

/**
 * Kakao 지도 역지오코딩 서비스
 * 좌표를 주소(도로명주소 또는 지번주소)로 변환합니다.
 *
 * Kakao API 문서: https://developers.kakao.com/docs/latest/ko/local/dev-guide#coord-to-address
 */
class GeocodingService {
  /**
   * 역지오코딩: 좌표 → 주소 변환
   * @param {number} latitude - 위도
   * @param {number} longitude - 경도
   * @returns {Promise<Object|null>} 주소 정보 객체 또는 null (실패 시)
   */
  static async reverseGeocode(latitude, longitude) {
    try {
      // Kakao API 인증 정보 확인
      const apiKey = process.env.KAKAO_REST_API_KEY;

      if (!apiKey) {
        errorLogger(new Error('Kakao API credentials not configured'), {
          context: 'reverseGeocode',
          message: 'KAKAO_REST_API_KEY is missing in .env',
        });
        return null;
      }

      debugLogger('Reverse geocoding request (Kakao)', {
        latitude,
        longitude,
      });

      // Kakao Maps coord2address API 호출
      const response = await axios.get('https://dapi.kakao.com/v2/local/geo/coord2address.json', {
        params: {
          x: longitude, // 경도
          y: latitude,  // 위도
        },
        headers: {
          Authorization: `KakaoAK ${apiKey}`,
        },
        timeout: 5000, // 5초 타임아웃
      });

      debugLogger('Reverse geocoding API response (Kakao)', {
        status: response.status,
        documentsCount: response.data.documents?.length || 0,
      });

      // 응답 데이터 파싱
      const documents = response.data.documents;
      if (!documents || documents.length === 0) {
        debugLogger('No results from reverse geocoding', {
          latitude,
          longitude,
        });
        return null;
      }

      const result = documents[0];

      // 도로명주소 우선, 없으면 지번주소
      let formattedAddress = null;
      let roadAddress = null;
      let jibunAddress = null;

      // 도로명주소 추출
      if (result.road_address) {
        const road = result.road_address;
        roadAddress = road.address_name;
        formattedAddress = roadAddress;

        debugLogger('Road address extracted (Kakao)', {
          roadAddress,
          rawData: {
            region_1depth_name: road.region_1depth_name,
            region_2depth_name: road.region_2depth_name,
            road_name: road.road_name,
            building_name: road.building_name,
          },
        });
      }

      // 지번주소 추출
      if (result.address) {
        const addr = result.address;
        jibunAddress = addr.address_name;

        // 도로명주소가 없으면 지번주소 사용
        if (!formattedAddress) {
          formattedAddress = jibunAddress;
        }

        debugLogger('Jibun address extracted (Kakao)', {
          jibunAddress,
          rawData: {
            region_1depth_name: addr.region_1depth_name,
            region_2depth_name: addr.region_2depth_name,
            region_3depth_name: addr.region_3depth_name,
            main_address_no: addr.main_address_no,
          },
        });
      }

      if (!formattedAddress) {
        debugLogger('Failed to format address from results', {
          documents: documents.length,
        });
        return null;
      }

      debugLogger('Reverse geocoding successful (Kakao)', {
        latitude,
        longitude,
        address: formattedAddress,
      });

      return {
        roadAddress,
        jibunAddress,
        formatted: formattedAddress,
        rawResults: documents, // 디버깅용
      };
    } catch (error) {
      // 네트워크 오류, API 오류, 타임아웃 등
      errorLogger(error, {
        context: 'reverseGeocode',
        latitude,
        longitude,
        errorMessage: error.message,
        errorCode: error.response?.status,
        errorData: error.response?.data,
      });

      return null;
    }
  }

  /**
   * 역지오코딩 결과를 포맷된 주소로 변환 (폴백 포함)
   * @param {number} latitude - 위도
   * @param {number} longitude - 경도
   * @returns {Promise<string>} 주소 문자열 (실패 시 좌표 기반 폴백)
   */
  static async getAddressOrFallback(latitude, longitude) {
    const result = await this.reverseGeocode(latitude, longitude);

    if (result && result.formatted) {
      return result.formatted;
    }

    // 폴백: 좌표 기반 임시 주소
    const fallbackAddress = `서울특별시 (${latitude.toFixed(4)}, ${longitude.toFixed(4)})`;

    debugLogger('Using fallback address', {
      latitude,
      longitude,
      fallbackAddress,
    });

    return fallbackAddress;
  }
}

module.exports = GeocodingService;
