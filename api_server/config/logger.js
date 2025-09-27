const winston = require('winston');
const path = require('path');

// 로그 디렉토리 생성
const logDir = path.join(__dirname, '../logs');
require('fs').mkdirSync(logDir, { recursive: true });

// 커스텀 로그 포맷
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.prettyPrint()
);

// 콘솔용 컬러 포맷
const consoleFormat = winston.format.combine(
  winston.format.timestamp({ format: 'HH:mm:ss' }),
  winston.format.colorize(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    let msg = `${timestamp} [${level}]: ${message}`;

    // 메타데이터가 있으면 추가
    if (Object.keys(meta).length > 0) {
      msg += `\\n${JSON.stringify(meta, null, 2)}`;
    }

    return msg;
  })
);

// Winston 로거 설정
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: { service: 'smoking-areas-api' },
  transports: [
    // 에러 로그 파일
    new winston.transports.File({
      filename: path.join(logDir, 'error.log'),
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5,
    }),

    // 모든 로그 파일
    new winston.transports.File({
      filename: path.join(logDir, 'combined.log'),
      maxsize: 5242880, // 5MB
      maxFiles: 10,
    }),
  ],
});

// 개발 환경에서는 콘솔에도 출력
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: consoleFormat,
  }));
}

// API 요청 로그 미들웨어
const apiLogger = (req, res, next) => {
  const start = Date.now();

  // 응답 완료 시 로그 출력
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logData = {
      method: req.method,
      url: req.originalUrl,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    };

    // 에러 상태코드면 warn, 정상이면 info
    if (res.statusCode >= 400) {
      logger.warn('API Request', logData);
    } else {
      logger.info('API Request', logData);
    }
  });

  next();
};

// SQL 쿼리 로그
const sqlLogger = (query, params = []) => {
  if (process.env.DEBUG_SQL === 'true') {
    logger.debug('SQL Query', {
      query: query.replace(/\\s+/g, ' ').trim(),
      params: params.length > 0 ? params : undefined,
    });
  }
};

// 에러 로그
const errorLogger = (error, context = {}) => {
  logger.error('Application Error', {
    message: error.message,
    stack: error.stack,
    ...context,
  });
};

// 디버그 로그
const debugLogger = (message, data = {}) => {
  if (process.env.DEBUG_API === 'true') {
    logger.debug(message, data);
  }
};

module.exports = {
  logger,
  apiLogger,
  sqlLogger,
  errorLogger,
  debugLogger,
};