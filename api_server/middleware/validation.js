const Joi = require('joi');
const { errorLogger } = require('../config/logger');

// 위치 검증 스키마
const locationSchema = Joi.object({
  lat: Joi.number().min(-90).max(90).required()
    .messages({
      'number.base': '위도는 숫자여야 합니다',
      'number.min': '위도는 -90도 이상이어야 합니다',
      'number.max': '위도는 90도 이하여야 합니다',
      'any.required': '위도는 필수입니다',
    }),
  lng: Joi.number().min(-180).max(180).required()
    .messages({
      'number.base': '경도는 숫자여야 합니다',
      'number.min': '경도는 -180도 이상이어야 합니다',
      'number.max': '경도는 180도 이하여야 합니다',
      'any.required': '경도는 필수입니다',
    }),
  radius: Joi.number().min(100).max(10000).default(1000)
    .messages({
      'number.base': '반경은 숫자여야 합니다',
      'number.min': '반경은 최소 100m입니다',
      'number.max': '반경은 최대 10km입니다',
    }),
  limit: Joi.number().min(1).max(100).default(20)
    .messages({
      'number.base': '제한 개수는 숫자여야 합니다',
      'number.min': '최소 1개 이상 요청해야 합니다',
      'number.max': '최대 100개까지 요청할 수 있습니다',
    }),
});

// ID 검증 스키마
const idSchema = Joi.object({
  id: Joi.number().integer().min(1).required()
    .messages({
      'number.base': 'ID는 숫자여야 합니다',
      'number.integer': 'ID는 정수여야 합니다',
      'number.min': 'ID는 1 이상이어야 합니다',
      'any.required': 'ID는 필수입니다',
    }),
});

// 카테고리 검증 스키마
const categorySchema = Joi.object({
  category: Joi.string().valid('부분 개방형', '완전 폐쇄형').required()
    .messages({
      'string.base': '카테고리는 문자열이어야 합니다',
      'any.only': '카테고리는 "부분 개방형" 또는 "완전 폐쇄형"이어야 합니다',
      'any.required': '카테고리는 필수입니다',
    }),
});

// 검증 미들웨어 생성 함수
const validate = (schema, property = 'query') => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[property], {
      abortEarly: false, // 모든 에러 표시
      stripUnknown: true, // 알 수 없는 속성 제거
    });

    if (error) {
      const errorDetails = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
        value: detail.context.value,
      }));

      errorLogger(error, {
        context: 'Validation error',
        property,
        details: errorDetails,
        requestPath: req.originalUrl,
      });

      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errorDetails,
      });
    }

    // 검증된 값으로 교체
    req[property] = value;
    next();
  };
};

// 헬스체크용 간단한 검증
const validateHealthCheck = (req, res, next) => {
  // 헬스체크는 항상 통과
  next();
};

module.exports = {
  validateLocation: validate(locationSchema, 'query'),
  validateId: validate(idSchema, 'params'),
  validateCategory: validate(categorySchema, 'params'),
  validateHealthCheck,

  // 개별 스키마도 내보내기 (테스트용)
  schemas: {
    locationSchema,
    idSchema,
    categorySchema,
  },
};