const express = require('express');
const SmokingAreaController = require('../controllers/smokingAreaController');
const {
  validateLocation,
  validateId,
  validateCategory,
} = require('../middleware/validation');
const { debugLogger } = require('../config/logger');

const router = express.Router();

// 라우터 레벨 미들웨어 - 요청 ID 생성
router.use((req, res, next) => {
  req.id = Math.random().toString(36).substr(2, 9);
  debugLogger('API request started', {
    requestId: req.id,
    method: req.method,
    path: req.originalUrl,
  });
  next();
});

/**
 * @route   GET /api/v1/smoking-areas
 * @desc    모든 흡연구역 조회
 * @access  Public
 * @example GET /api/v1/smoking-areas
 */
router.get('/', SmokingAreaController.getAllAreas);

/**
 * @route   POST /api/v1/smoking-areas/pending
 * @desc    새로운 흡연구역 등록 신청 (대기 상태)
 * @access  Public
 * @example POST /api/v1/smoking-areas/pending
 */
router.post('/pending', SmokingAreaController.createPendingArea);

/**
 * @route   GET /api/v1/smoking-areas/nearby
 * @desc    주변 흡연구역 검색
 * @access  Public
 * @query   {number} lat - 위도 (-90 ~ 90)
 * @query   {number} lng - 경도 (-180 ~ 180)
 * @query   {number} [radius=1000] - 검색 반경 (미터, 100-10000)
 * @query   {number} [limit=20] - 결과 개수 제한 (1-100)
 * @example GET /api/v1/smoking-areas/nearby?lat=37.5547&lng=126.9707&radius=1000&limit=10
 */
router.get('/nearby', validateLocation, SmokingAreaController.getNearbyAreas);

/**
 * @route   GET /api/v1/smoking-areas/category/:category
 * @desc    카테고리별 흡연구역 조회
 * @access  Public
 * @param   {string} category - 흡연구역 카테고리 (부분 개방형, 완전 폐쇄형)
 * @example GET /api/v1/smoking-areas/category/부분 개방형
 */
router.get('/category/:category', validateCategory, SmokingAreaController.getAreasByCategory);

/**
 * @route   GET /api/v1/smoking-areas/pending
 * @desc    대기 중인 흡연구역 목록 조회 (관리자용)
 * @access  Admin
 * @example GET /api/v1/smoking-areas/pending
 */
router.get('/pending', SmokingAreaController.getPendingAreas);

/**
 * @route   GET /api/v1/smoking-areas/statistics
 * @desc    흡연구역 통계 정보 조회
 * @access  Public
 * @example GET /api/v1/smoking-areas/statistics
 */
router.get('/statistics', SmokingAreaController.getStatistics);

/**
 * @route   PATCH /api/v1/smoking-areas/:id/approve
 * @desc    흡연구역 승인 (관리자용)
 * @access  Admin
 * @example PATCH /api/v1/smoking-areas/123/approve
 */
router.patch('/:id/approve', validateId, SmokingAreaController.approveArea);

/**
 * @route   DELETE /api/v1/smoking-areas/:id/reject
 * @desc    흡연구역 거부 (관리자용)
 * @access  Admin
 * @example DELETE /api/v1/smoking-areas/123/reject
 */
router.delete('/:id/reject', validateId, SmokingAreaController.rejectArea);

/**
 * @route   GET /api/v1/smoking-areas/:id
 * @desc    특정 흡연구역 상세 조회
 * @access  Public
 * @param   {number} id - 흡연구역 ID
 * @example GET /api/v1/smoking-areas/123
 */
router.get('/:id', validateId, SmokingAreaController.getAreaById);

module.exports = router;