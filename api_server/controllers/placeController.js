const axios = require('axios');
const { logger, errorLogger, debugLogger } = require('../config/logger');

class PlaceController {
  /**
   * @route   GET /api/v1/places/search
   * @desc    장소 검색 (카카오 Local API 프록시)
   * @access  Public
   * @query   {string} query - 검색어
   * @query   {number} [x] - 경도 (WGS84)
   * @query   {number} [y] - 위도 (WGS84)
   * @query   {number} [radius] - 반경(m)
   * @query   {number} [size=15] - 한 페이지에 보여질 문서의 개수 (1-15)
   * @example GET /api/v1/places/search?query=강남역&x=127.027583&y=37.497942
   */
  static async searchPlaces(req, res) {
    const { requestId } = req;
    const { query, x, y, radius, size = 15 } = req.query;

    try {
      debugLogger('Place search request', {
        requestId,
        query,
        x,
        y,
        radius,
        size,
      });

      // Kakao REST API 키 확인
      const kakaoApiKey = process.env.KAKAO_REST_API_KEY;
      if (!kakaoApiKey) {
        return res.status(500).json({
          success: false,
          error: 'Kakao API key not configured',
        });
      }

      // 카카오 Local API 키워드 검색 호출
      const kakaoUrl = 'https://dapi.kakao.com/v2/local/search/keyword.json';
      const params = {
        query,
        x,
        y,
        radius,
        size: Math.min(Math.max(1, parseInt(size) || 15), 15), // 1-15 제한
      };

      // undefined 값 제거
      Object.keys(params).forEach(key => {
        if (params[key] === undefined) {
          delete params[key];
        }
      });

      const response = await axios.get(kakaoUrl, {
        headers: {
          'Authorization': `KakaoAK ${kakaoApiKey}`,
          'Content-Type': 'application/json',
        },
        params,
        timeout: 5000, // 5초 타임아웃
      });

      const { documents, meta } = response.data;

      // 응답 데이터 정규화
      const places = documents.map(place => ({
        id: place.id,
        placeName: place.place_name,
        categoryName: place.category_name,
        categoryGroupCode: place.category_group_code,
        phone: place.phone,
        addressName: place.address_name,
        roadAddressName: place.road_address_name,
        x: parseFloat(place.x), // 경도
        y: parseFloat(place.y), // 위도
        placeUrl: place.place_url,
        distance: place.distance,
      }));

      debugLogger('Place search completed', {
        requestId,
        query,
        resultsCount: places.length,
        totalCount: meta.total_count,
        isEnd: meta.is_end,
      });

      res.json({
        success: true,
        data: {
          places,
          meta: {
            totalCount: meta.total_count,
            pageableCount: meta.pageable_count,
            isEnd: meta.is_end,
            sameName: meta.same_name,
          },
        },
      });
    } catch (error) {
      errorLogger('Place search error', {
        requestId,
        query,
        error: error.message,
        stack: error.stack,
      });

      if (error.response) {
        // 카카오 API 에러
        const { status, data } = error.response;
        return res.status(status === 401 ? 500 : status).json({
          success: false,
          error: status === 401 ? 'API authentication failed' : data?.errorType || 'External API error',
        });
      }

      if (error.code === 'ECONNABORTED') {
        return res.status(408).json({
          success: false,
          error: 'Search request timeout',
        });
      }

      res.status(500).json({
        success: false,
        error: 'Internal server error',
      });
    }
  }
}

module.exports = PlaceController;