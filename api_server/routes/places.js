const express = require('express');
const PlaceController = require('../controllers/placeController');
const { debugLogger } = require('../config/logger');
const Joi = require('joi');

const router = express.Router();

// 라우터 레벨 미들웨어 - 요청 ID 생성
router.use((req, res, next) => {
  req.requestId = Math.random().toString(36).substr(2, 9);
  debugLogger('Places API request started', {
    requestId: req.requestId,
    method: req.method,
    path: req.originalUrl,
  });
  next();
});

// 검색 요청 검증 미들웨어
const validateSearchQuery = (req, res, next) => {
  const schema = Joi.object({
    query: Joi.string().trim().min(1).max(100).required()
      .messages({
        'string.empty': '검색어를 입력해주세요',
        'string.min': '검색어는 최소 1자 이상이어야 합니다',
        'string.max': '검색어는 최대 100자까지 가능합니다',
        'any.required': '검색어를 입력해주세요',
      }),
    x: Joi.number().min(-180).max(180).optional()
      .messages({
        'number.base': '경도는 숫자여야 합니다',
        'number.min': '경도는 -180 이상이어야 합니다',
        'number.max': '경도는 180 이하여야 합니다',
      }),
    y: Joi.number().min(-90).max(90).optional()
      .messages({
        'number.base': '위도는 숫자여야 합니다',
        'number.min': '위도는 -90 이상이어야 합니다',
        'number.max': '위도는 90 이하여야 합니다',
      }),
    radius: Joi.number().min(100).max(20000).optional()
      .messages({
        'number.base': '반경은 숫자여야 합니다',
        'number.min': '반경은 최소 100m 이상이어야 합니다',
        'number.max': '반경은 최대 20,000m 이하여야 합니다',
      }),
    size: Joi.number().min(1).max(15).optional()
      .messages({
        'number.base': '페이지 크기는 숫자여야 합니다',
        'number.min': '페이지 크기는 최소 1 이상이어야 합니다',
        'number.max': '페이지 크기는 최대 15 이하여야 합니다',
      }),
  });

  const { error } = schema.validate(req.query);
  if (error) {
    debugLogger('Places search validation error', {
      requestId: req.requestId,
      error: error.details[0].message,
      query: req.query,
    });

    return res.status(400).json({
      success: false,
      error: error.details[0].message,
    });
  }

  next();
};

/**
 * @route   GET /api/v1/places/search
 * @desc    장소 검색 (카카오 Local API 프록시)
 * @access  Public
 * @query   {string} query - 검색어 (필수)
 * @query   {number} [x] - 경도 (WGS84, 선택)
 * @query   {number} [y] - 위도 (WGS84, 선택)
 * @query   {number} [radius] - 반경(m, 100-20000, 선택)
 * @query   {number} [size] - 페이지 크기 (1-15, 기본값 15, 선택)
 * @example GET /api/v1/places/search?query=강남역&x=127.027583&y=37.497942
 */
router.get('/search', validateSearchQuery, PlaceController.searchPlaces);

module.exports = router;