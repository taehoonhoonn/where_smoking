const { query } = require('../config/database');
const { debugLogger, errorLogger } = require('../config/logger');

class SmokingAreaController {
  // 모든 흡연구역 조회
  static async getAllAreas(req, res) {
    try {
      debugLogger('Getting all smoking areas');

      const result = await query(`
        SELECT
          id, category, address, detail, postal_code,
          longitude, latitude, created_at
        FROM smoking_areas
        WHERE status = 'active'
        ORDER BY id
      `);

      const response = {
        success: true,
        count: result.rows.length,
        smoking_areas: result.rows.map(row => ({
          id: row.id,
          category: row.category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          created_at: row.created_at,
        })),
      };

      debugLogger('Successfully retrieved all smoking areas', {
        count: result.rows.length,
      });

      res.json(response);
    } catch (error) {
      errorLogger(error, {
        context: 'getAllAreas',
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to retrieve smoking areas',
      });
    }
  }

  // 주변 흡연구역 검색
  static async getNearbyAreas(req, res) {
    try {
      const { lat, lng, radius, limit } = req.query;

      debugLogger('Searching nearby smoking areas', {
        latitude: lat,
        longitude: lng,
        radius,
        limit,
      });

      // 하버사인 공식을 사용한 거리 계산 쿼리
      const result = await query(`
        SELECT
          id, category, address, detail, postal_code,
          longitude, latitude, created_at,
          (
            6371000 * acos(
              cos(radians($1)) * cos(radians(latitude)) *
              cos(radians(longitude) - radians($2)) +
              sin(radians($1)) * sin(radians(latitude))
            )
          ) AS distance_meters
        FROM smoking_areas
        WHERE status = 'active'
          AND (
            6371000 * acos(
              cos(radians($1)) * cos(radians(latitude)) *
              cos(radians(longitude) - radians($2)) +
              sin(radians($1)) * sin(radians(latitude))
            )
          ) <= $3
        ORDER BY distance_meters ASC
        LIMIT $4
      `, [lat, lng, radius, limit]);

      const response = {
        success: true,
        query: {
          latitude: parseFloat(lat),
          longitude: parseFloat(lng),
          radius_meters: parseInt(radius),
          limit: parseInt(limit),
        },
        count: result.rows.length,
        smoking_areas: result.rows.map(row => ({
          id: row.id,
          category: row.category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          distance_meters: Math.round(parseFloat(row.distance_meters)),
          created_at: row.created_at,
        })),
      };

      debugLogger('Successfully found nearby smoking areas', {
        found: result.rows.length,
        searchRadius: radius,
      });

      res.json(response);
    } catch (error) {
      errorLogger(error, {
        context: 'getNearbyAreas',
        params: req.query,
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to search nearby areas',
      });
    }
  }

  // 특정 흡연구역 상세 조회
  static async getAreaById(req, res) {
    try {
      const { id } = req.params;

      debugLogger('Getting smoking area by ID', { id });

      const result = await query(`
        SELECT
          id, category, address, detail, postal_code,
          longitude, latitude, created_at, updated_at
        FROM smoking_areas
        WHERE id = $1 AND status = 'active'
      `, [id]);

      if (result.rows.length === 0) {
        debugLogger('Smoking area not found', { id });

        return res.status(404).json({
          success: false,
          error: 'Not found',
          message: `Smoking area with ID ${id} not found`,
        });
      }

      const row = result.rows[0];
      const response = {
        success: true,
        smoking_area: {
          id: row.id,
          category: row.category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          created_at: row.created_at,
          updated_at: row.updated_at,
        },
      };

      debugLogger('Successfully retrieved smoking area', { id });

      res.json(response);
    } catch (error) {
      errorLogger(error, {
        context: 'getAreaById',
        params: req.params,
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to retrieve smoking area',
      });
    }
  }

  // 카테고리별 흡연구역 조회
  static async getAreasByCategory(req, res) {
    try {
      const { category } = req.params;

      debugLogger('Getting smoking areas by category', { category });

      const result = await query(`
        SELECT
          id, category, address, detail, postal_code,
          longitude, latitude, created_at
        FROM smoking_areas
        WHERE category = $1 AND status = 'active'
        ORDER BY address
      `, [category]);

      const response = {
        success: true,
        category,
        count: result.rows.length,
        smoking_areas: result.rows.map(row => ({
          id: row.id,
          category: row.category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          created_at: row.created_at,
        })),
      };

      debugLogger('Successfully retrieved areas by category', {
        category,
        count: result.rows.length,
      });

      res.json(response);
    } catch (error) {
      errorLogger(error, {
        context: 'getAreasByCategory',
        params: req.params,
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to retrieve areas by category',
      });
    }
  }

  // 통계 정보 조회
  static async getStatistics(req, res) {
    try {
      debugLogger('Getting smoking areas statistics');

      const totalResult = await query(`
        SELECT COUNT(*) as total_count
        FROM smoking_areas
        WHERE status = 'active'
      `);

      const categoryResult = await query(`
        SELECT
          category,
          COUNT(*) as count
        FROM smoking_areas
        WHERE status = 'active'
        GROUP BY category
        ORDER BY count DESC
      `);

      const districtResult = await query(`
        SELECT
          CASE
            WHEN address LIKE '%중구%' THEN '중구'
            WHEN address LIKE '%용산구%' THEN '용산구'
            WHEN address LIKE '%성동구%' THEN '성동구'
            WHEN address LIKE '%광진구%' THEN '광진구'
            WHEN address LIKE '%동대문구%' THEN '동대문구'
            WHEN address LIKE '%노원구%' THEN '노원구'
            WHEN address LIKE '%강서구%' THEN '강서구'
            ELSE '기타'
          END as district,
          COUNT(*) as count
        FROM smoking_areas
        WHERE status = 'active'
        GROUP BY district
        ORDER BY count DESC
      `);

      const response = {
        success: true,
        statistics: {
          total_areas: parseInt(totalResult.rows[0].total_count),
          by_category: categoryResult.rows.map(row => ({
            category: row.category,
            count: parseInt(row.count),
          })),
          by_district: districtResult.rows.map(row => ({
            district: row.district,
            count: parseInt(row.count),
          })),
          last_updated: new Date().toISOString(),
        },
      };

      debugLogger('Successfully retrieved statistics', {
        totalAreas: response.statistics.total_areas,
      });

      res.json(response);
    } catch (error) {
      errorLogger(error, {
        context: 'getStatistics',
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to retrieve statistics',
      });
    }
  }

  /**
   * 새로운 흡연구역 등록 신청 (대기 상태로 저장)
   */
  static async createPendingArea(req, res) {
    try {
      const { latitude, longitude, category, detail } = req.body;

      // 입력 유효성 검증
      if (!latitude || !longitude || !category) {
        return res.status(400).json({
          success: false,
          error: 'Validation error',
          message: '위도, 경도, 카테고리는 필수입니다.',
        });
      }

      // 위도/경도 범위 검증 (서울 지역 대략적 범위)
      if (latitude < 37.3 || latitude > 37.8 || longitude < 126.5 || longitude > 127.3) {
        return res.status(400).json({
          success: false,
          error: 'Validation error',
          message: '서울 지역 내의 좌표만 등록 가능합니다.',
        });
      }

      // 카테고리 검증
      if (!['부분 개방형', '완전 폐쇄형'].includes(category)) {
        return res.status(400).json({
          success: false,
          error: 'Validation error',
          message: '유효하지 않은 카테고리입니다.',
        });
      }

      debugLogger('Creating pending smoking area', {
        latitude,
        longitude,
        category,
        detail: detail ? 'provided' : 'not provided',
      });

      // 역지오코딩으로 주소 가져오기 (임시로 좌표 기반 주소 생성)
      const address = `서울특별시 (${latitude.toFixed(4)}, ${longitude.toFixed(4)})`;

      // 데이터베이스에 대기 상태로 저장
      const result = await query(`
        INSERT INTO smoking_areas (
          category, address, detail, postal_code,
          longitude, latitude, status, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, 'pending', NOW(), NOW())
        RETURNING id, created_at
      `, [
        category,
        address,
        detail || null,
        null, // postal_code는 나중에 관리자가 수정
        longitude,
        latitude
      ]);

      const newArea = result.rows[0];

      debugLogger('Successfully created pending smoking area', {
        id: newArea.id,
        category,
        status: 'pending',
      });

      res.status(201).json({
        success: true,
        message: '흡연구역 등록 신청이 완료되었습니다. 관리자 검토 후 반영됩니다.',
        smoking_area: {
          id: newArea.id,
          category,
          address,
          detail: detail || null,
          coordinates: {
            latitude: parseFloat(latitude),
            longitude: parseFloat(longitude),
          },
          status: 'pending',
          created_at: newArea.created_at,
        },
      });

    } catch (error) {
      errorLogger(error, {
        context: 'createPendingArea',
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: '등록 신청 처리 중 오류가 발생했습니다.',
      });
    }
  }

  /**
   * 대기 중인 흡연구역 목록 조회 (관리자용)
   */
  static async getPendingAreas(req, res) {
    try {
      debugLogger('Getting pending smoking areas');

      const result = await query(`
        SELECT
          id, category, address, detail, postal_code,
          longitude, latitude, created_at
        FROM smoking_areas
        WHERE status = 'pending'
        ORDER BY created_at DESC
      `);

      const response = {
        success: true,
        count: result.rows.length,
        pending_areas: result.rows.map(row => ({
          id: row.id,
          category: row.category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          created_at: row.created_at,
        })),
      };

      debugLogger('Successfully retrieved pending areas', {
        count: result.rows.length,
      });

      res.json(response);
    } catch (error) {
      errorLogger(error, {
        context: 'getPendingAreas',
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to retrieve pending areas',
      });
    }
  }

  /**
   * 흡연구역 승인 (관리자용)
   */
  static async approveArea(req, res) {
    try {
      const { id } = req.params;

      debugLogger('Approving smoking area', { id });

      // 해당 ID의 pending 상태 확인
      const checkResult = await query(`
        SELECT id, category, address
        FROM smoking_areas
        WHERE id = $1 AND status = 'pending'
      `, [id]);

      if (checkResult.rows.length === 0) {
        debugLogger('Pending area not found', { id });

        return res.status(404).json({
          success: false,
          error: 'Not found',
          message: `Pending area with ID ${id} not found`,
        });
      }

      // 상태를 active로 변경
      const result = await query(`
        UPDATE smoking_areas
        SET status = 'active', updated_at = NOW()
        WHERE id = $1 AND status = 'pending'
        RETURNING id, category, address, updated_at
      `, [id]);

      const approvedArea = result.rows[0];

      debugLogger('Successfully approved smoking area', {
        id: approvedArea.id,
        category: approvedArea.category,
      });

      res.json({
        success: true,
        message: '흡연구역이 승인되어 활성화되었습니다.',
        smoking_area: {
          id: approvedArea.id,
          category: approvedArea.category,
          address: approvedArea.address,
          status: 'active',
          approved_at: approvedArea.updated_at,
        },
      });

    } catch (error) {
      errorLogger(error, {
        context: 'approveArea',
        params: req.params,
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to approve smoking area',
      });
    }
  }

  /**
   * 흡연구역 거부 (관리자용)
   */
  static async rejectArea(req, res) {
    try {
      const { id } = req.params;
      const { reason } = req.body;

      debugLogger('Rejecting smoking area', { id, reason: reason ? 'provided' : 'not provided' });

      // 해당 ID의 pending 상태 확인
      const checkResult = await query(`
        SELECT id, category, address
        FROM smoking_areas
        WHERE id = $1 AND status = 'pending'
      `, [id]);

      if (checkResult.rows.length === 0) {
        debugLogger('Pending area not found', { id });

        return res.status(404).json({
          success: false,
          error: 'Not found',
          message: `Pending area with ID ${id} not found`,
        });
      }

      // 상태를 rejected로 변경하거나 삭제
      const result = await query(`
        UPDATE smoking_areas
        SET status = 'rejected', detail = COALESCE($2, detail), updated_at = NOW()
        WHERE id = $1 AND status = 'pending'
        RETURNING id, category, address, updated_at
      `, [id, reason]);

      const rejectedArea = result.rows[0];

      debugLogger('Successfully rejected smoking area', {
        id: rejectedArea.id,
        category: rejectedArea.category,
      });

      res.json({
        success: true,
        message: '흡연구역 등록 신청이 거부되었습니다.',
        smoking_area: {
          id: rejectedArea.id,
          category: rejectedArea.category,
          address: rejectedArea.address,
          status: 'rejected',
          rejected_at: rejectedArea.updated_at,
          reason: reason || null,
        },
      });

    } catch (error) {
      errorLogger(error, {
        context: 'rejectArea',
        params: req.params,
        body: req.body,
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to reject smoking area',
      });
    }
  }
}

module.exports = SmokingAreaController;