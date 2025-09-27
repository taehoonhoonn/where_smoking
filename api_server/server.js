require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

const { logger, apiLogger, errorLogger, debugLogger } = require('./config/logger');
const { checkConnection } = require('./config/database');

// 라우터 임포트
const smokingAreasRoutes = require('./routes/smokingAreas');
const healthRoutes = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 3000;
const API_VERSION = process.env.API_VERSION || 'v1';

// 전역 에러 핸들러
process.on('uncaughtException', (error) => {
  errorLogger(error, { context: 'Uncaught Exception' });
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  errorLogger(new Error(reason), {
    context: 'Unhandled Rejection',
    promise: promise.toString(),
  });
});

// 미들웨어 설정
app.use(helmet()); // 보안 헤더
app.use(compression()); // 응답 압축

// CORS 설정
const corsOptions = {
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};
app.use(cors(corsOptions));

// Rate Limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15분
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // 요청 제한
  message: {
    success: false,
    error: 'Too many requests',
    message: 'Rate limit exceeded. Please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// JSON 파싱
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// API 로깅 미들웨어
app.use(apiLogger);

// 루트 엔드포인트
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: '흡연구역 찾기 API 서버',
    version: require('./package.json').version,
    environment: process.env.NODE_ENV || 'development',
    endpoints: {
      health: `/api/${API_VERSION}/health`,
      smoking_areas: `/api/${API_VERSION}/smoking-areas`,
      nearby_search: `/api/${API_VERSION}/smoking-areas/nearby`,
      statistics: `/api/${API_VERSION}/smoking-areas/statistics`,
    },
    documentation: {
      swagger: `/api/${API_VERSION}/docs`, // TODO: Swagger 문서 추가
    },
  });
});

// API 라우터 등록
app.use(`/api/${API_VERSION}/health`, healthRoutes);
app.use(`/api/${API_VERSION}/smoking-areas`, smokingAreasRoutes);

// 404 핸들러
app.use('*', (req, res) => {
  debugLogger('404 Not Found', {
    method: req.method,
    url: req.originalUrl,
    ip: req.ip,
  });

  res.status(404).json({
    success: false,
    error: 'Not Found',
    message: `Route ${req.method} ${req.originalUrl} not found`,
  });
});

// 전역 에러 핸들러
app.use((error, req, res, next) => {
  errorLogger(error, {
    context: 'Express Error Handler',
    method: req.method,
    url: req.originalUrl,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });

  res.status(error.status || 500).json({
    success: false,
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong',
    ...(process.env.NODE_ENV === 'development' && { stack: error.stack }),
  });
});

// 서버 시작
const startServer = async () => {
  try {
    // 데이터베이스 연결 확인
    const dbConnected = await checkConnection();
    if (!dbConnected) {
      throw new Error('Database connection failed');
    }

    debugLogger('Database connection successful');

    // 서버 시작
    const server = app.listen(PORT, () => {
      logger.info(`🚀 Server started successfully`, {
        port: PORT,
        environment: process.env.NODE_ENV || 'development',
        apiVersion: API_VERSION,
        pid: process.pid,
      });

      console.log(`
╔══════════════════════════════════════════╗
║          흡연구역 찾기 API 서버              ║
╠══════════════════════════════════════════╣
║ 🌐 Server: http://localhost:${PORT}${' '.repeat(Math.max(0, 8 - PORT.toString().length))} ║
║ 📊 Health: /api/${API_VERSION}/health${' '.repeat(Math.max(0, 15 - API_VERSION.length))} ║
║ 🚬 Areas:  /api/${API_VERSION}/smoking-areas${' '.repeat(Math.max(0, 6 - API_VERSION.length))} ║
║ 📈 Stats:  /api/${API_VERSION}/smoking-areas/statistics ║
╚══════════════════════════════════════════╝
      `);
    });

    // Graceful shutdown
    const gracefulShutdown = (signal) => {
      logger.info(`Received ${signal}. Starting graceful shutdown...`);

      server.close((err) => {
        if (err) {
          errorLogger(err, { context: 'Server shutdown' });
          process.exit(1);
        }

        logger.info('Server closed successfully');
        process.exit(0);
      });

      // 강제 종료 (30초 후)
      setTimeout(() => {
        logger.error('Forcing server shutdown after timeout');
        process.exit(1);
      }, 30000);
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

  } catch (error) {
    errorLogger(error, { context: 'Server startup' });
    console.error('❌ Failed to start server:', error.message);
    process.exit(1);
  }
};

// 서버 시작
if (require.main === module) {
  startServer();
}

module.exports = app;