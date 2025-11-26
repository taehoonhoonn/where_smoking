const { query } = require('../config/database');
const { debugLogger, errorLogger } = require('../config/logger');

const SUBMITTED_CATEGORY_OPTIONS = [
  { key: 'official', label: '공식 흡연장소' },
  { key: 'unofficial', label: '비공식 흡연장소' },
];

const SUBMITTED_CATEGORY_LOOKUP = SUBMITTED_CATEGORY_OPTIONS.reduce(
  (acc, option) => {
    acc[option.key] = option.label;
    acc[option.label] = option.label;
    acc[option.label.replace(/\s+/g, '')] = option.label;
    return acc;
  },
  {},
);

function resolveSubmittedCategory(rawCategory) {
  if (typeof rawCategory !== 'string') {
    return null;
  }

  const trimmed = rawCategory.trim();
  if (!trimmed) {
    return null;
  }

  const directMatch = SUBMITTED_CATEGORY_LOOKUP[trimmed];
  if (directMatch) {
    return directMatch;
  }

  const lowerKeyMatch = SUBMITTED_CATEGORY_LOOKUP[trimmed.toLowerCase()];
  if (lowerKeyMatch) {
    return lowerKeyMatch;
  }

  const compactKeyMatch = SUBMITTED_CATEGORY_LOOKUP[trimmed.replace(/\s+/g, '')];
  if (compactKeyMatch) {
    return compactKeyMatch;
  }

  return null;
}

class SmokingAreaController {
  // 모든 흡연구역 조회
  static async getAllAreas(req, res) {
    try {
      debugLogger('Getting all smoking areas');

      const result = await query(`
        SELECT
          id, category, submitted_category, address, detail, postal_code,
          longitude, latitude, report_count, created_at
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
          submitted_category: row.submitted_category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          report_count: parseInt(row.report_count, 10) || 0,
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
          id, category, submitted_category, address, detail, postal_code,
          longitude, latitude, report_count, created_at,
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
          report_count: parseInt(row.report_count, 10) || 0,
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
          id, category, submitted_category, address, detail, postal_code,
          longitude, latitude, report_count, created_at, updated_at
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
          submitted_category: row.submitted_category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          report_count: parseInt(row.report_count, 10) || 0,
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
          id, category, submitted_category, address, detail, postal_code,
          longitude, latitude, report_count, created_at
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
          report_count: parseInt(row.report_count, 10) || 0,
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
      const { latitude, longitude, detail, category } = req.body;
      const storedCategory = '시민제보';
      const submittedCategory = resolveSubmittedCategory(category);

      if (!submittedCategory) {
        return res.status(400).json({
          success: false,
          error: 'Validation error',
          message: '등록 유형을 선택해주세요. (공식 흡연장소 또는 비공식 흡연장소)',
        });
      }

      const latNum = Number(latitude);
      const lngNum = Number(longitude);

      // 입력 유효성 검증
      if (!Number.isFinite(latNum) || !Number.isFinite(lngNum)) {
        return res.status(400).json({
          success: false,
          error: 'Validation error',
          message: '유효한 위도와 경도를 입력하세요.',
        });
      }

      // 위도/경도 범위 검증 (서울 지역 대략적 범위)
      if (latNum < 37.3 || latNum > 37.8 || lngNum < 126.5 || lngNum > 127.3) {
        return res.status(400).json({
          success: false,
          error: 'Validation error',
          message: '서울 지역 내의 좌표만 등록 가능합니다.',
        });
      }

      debugLogger('Creating pending smoking area', {
        latitude: latNum,
        longitude: lngNum,
        category: storedCategory,
        submittedCategory,
        detail: detail ? 'provided' : 'not provided',
      });

      // 역지오코딩으로 주소 가져오기 (임시로 좌표 기반 주소 생성)
      const address = `서울특별시 (${latNum.toFixed(4)}, ${lngNum.toFixed(4)})`;

      // 데이터베이스에 대기 상태로 저장
      const result = await query(`
        INSERT INTO smoking_areas (
          category, submitted_category, address, detail, postal_code,
          longitude, latitude, status, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', NOW(), NOW())
        RETURNING id, created_at
      `, [
        storedCategory,
        submittedCategory,
        address,
        detail || null,
        null, // postal_code는 나중에 관리자가 수정
        lngNum,
        latNum
      ]);

      const newArea = result.rows[0];

      debugLogger('Successfully created pending smoking area', {
        id: newArea.id,
        category: storedCategory,
        submittedCategory,
        status: 'pending',
      });

      res.status(201).json({
        success: true,
        message: '흡연구역 등록 신청이 완료되었습니다. 관리자 검토 후 반영됩니다.',
        smoking_area: {
          id: newArea.id,
          category: storedCategory,
          submitted_category: submittedCategory,
          address,
          detail: detail || null,
          coordinates: {
            latitude: latNum,
            longitude: lngNum,
          },
          status: 'pending',
          report_count: 0,
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
          id, category, submitted_category, address, detail, postal_code,
          longitude, latitude, report_count, created_at
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
          submitted_category: row.submitted_category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          report_count: parseInt(row.report_count, 10) || 0,
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

  // 신고된 흡연구역 목록 조회 (관리자용)
  static async getReportedAreas(req, res) {
    try {
      debugLogger('Getting reported smoking areas');

      const result = await query(`
        SELECT
          id, category, submitted_category, address, detail, postal_code,
          longitude, latitude, report_count, created_at, updated_at
        FROM smoking_areas
        WHERE report_count > 0 AND status = 'active'
        ORDER BY report_count DESC, updated_at DESC
      `);

      const response = {
        success: true,
        count: result.rows.length,
        reported_areas: result.rows.map(row => ({
          id: row.id,
          category: row.category,
          submitted_category: row.submitted_category,
          address: row.address,
          detail: row.detail,
          postal_code: row.postal_code,
          coordinates: {
            longitude: parseFloat(row.longitude),
            latitude: parseFloat(row.latitude),
          },
          report_count: parseInt(row.report_count, 10) || 0,
          created_at: row.created_at,
          updated_at: row.updated_at,
        })),
      };

      debugLogger('Successfully retrieved reported areas', {
        count: result.rows.length,
        totalReports: result.rows.reduce((sum, row) => sum + (parseInt(row.report_count, 10) || 0), 0),
      });

      res.json(response);
    } catch (error) {
      errorLogger(error, {
        context: 'getReportedAreas',
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to retrieve reported areas',
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
        SELECT id, category, submitted_category, address
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
        SET category = '시민제보', status = 'active', updated_at = NOW()
        WHERE id = $1 AND status = 'pending'
        RETURNING id, category, submitted_category, address, report_count, updated_at
      `, [id]);

      const approvedArea = result.rows[0];

      debugLogger('Successfully approved smoking area', {
        id: approvedArea.id,
        category: approvedArea.category,
        submittedCategory: approvedArea.submitted_category,
      });

      res.json({
        success: true,
        message: '흡연구역이 승인되어 활성화되었습니다.',
        smoking_area: {
          id: approvedArea.id,
          category: approvedArea.category,
          submitted_category: approvedArea.submitted_category,
          address: approvedArea.address,
          report_count: parseInt(approvedArea.report_count, 10) || 0,
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
        SELECT id, category, submitted_category, address
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
        RETURNING id, category, submitted_category, address, report_count, updated_at
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
          submitted_category: rejectedArea.submitted_category,
          address: rejectedArea.address,
          status: 'rejected',
          rejected_at: rejectedArea.updated_at,
          reason: reason || null,
          report_count: parseInt(rejectedArea.report_count, 10) || 0,
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

  /**
   * 활성화된 흡연구역 삭제 (관리자용)
   */
  static async deleteArea(req, res) {
    try {
      const { id } = req.params;

      debugLogger('Deleting smoking area', { id });

      const result = await query(`
        UPDATE smoking_areas
        SET status = 'deleted', updated_at = NOW()
        WHERE id = $1 AND status = 'active'
        RETURNING id, category, submitted_category, address, report_count, updated_at
      `, [id]);

      if (result.rows.length === 0) {
        debugLogger('Active smoking area not found for deletion', { id });

        return res.status(404).json({
          success: false,
          error: 'Not found',
          message: `Active smoking area with ID ${id} not found`,
        });
      }

      const deletedArea = result.rows[0];

      debugLogger('Successfully deleted smoking area', {
        id: deletedArea.id,
        category: deletedArea.category,
      });

      res.json({
        success: true,
        message: '흡연구역이 지도에서 제거되었습니다.',
        smoking_area: {
          id: deletedArea.id,
          category: deletedArea.category,
          submitted_category: deletedArea.submitted_category,
          address: deletedArea.address,
          status: 'deleted',
          deleted_at: deletedArea.updated_at,
          report_count: parseInt(deletedArea.report_count, 10) || 0,
        },
      });

    } catch (error) {
      errorLogger(error, {
        context: 'deleteArea',
        params: req.params,
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to delete smoking area',
      });
    }
  }

  /**
   * 허위 장소 신고 처리
   */
  static async reportFalseArea(req, res) {
    try {
      const { id } = req.params;

      debugLogger('Reporting smoking area as false', { id });

      const result = await query(`
        UPDATE smoking_areas
        SET report_count = COALESCE(report_count, 0) + 1, updated_at = NOW()
        WHERE id = $1
        RETURNING id, category, report_count
      `, [id]);

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Not found',
          message: `Smoking area with ID ${id} not found`,
        });
      }

      const updated = result.rows[0];

      res.json({
        success: true,
        message: '허위 장소 신고가 접수되었습니다.',
        smoking_area: {
          id: updated.id,
          category: updated.category,
          report_count: parseInt(updated.report_count, 10) || 0,
        },
      });

    } catch (error) {
      errorLogger(error, {
        context: 'reportFalseArea',
        params: req.params,
        requestId: req.id,
      });

      res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: 'Failed to report smoking area',
      });
    }
  }
}

module.exports = SmokingAreaController;
