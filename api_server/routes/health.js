const express = require('express');
const { checkConnection, getConnectionStats } = require('../config/database');
const { debugLogger, errorLogger } = require('../config/logger');

const router = express.Router();

/**
 * @route   GET /api/v1/health
 * @desc    서버 헬스체크
 * @access  Public
 */
router.get('/', async (req, res) => {
  try {
    const startTime = Date.now();

    // 데이터베이스 연결 확인
    const dbConnected = await checkConnection();
    const dbStats = getConnectionStats();

    const healthCheck = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      version: require('../package.json').version,
      database: {
        connected: dbConnected,
        connection_pool: dbStats,
      },
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        external: Math.round(process.memoryUsage().external / 1024 / 1024),
      },
      response_time: Date.now() - startTime,
    };

    // 데이터베이스 연결 실패 시 상태 변경
    if (!dbConnected) {
      healthCheck.status = 'degraded';
      healthCheck.issues = ['Database connection failed'];
    }

    debugLogger('Health check performed', {
      status: healthCheck.status,
      dbConnected,
      responseTime: healthCheck.response_time,
    });

    const statusCode = healthCheck.status === 'ok' ? 200 : 503;
    res.status(statusCode).json(healthCheck);

  } catch (error) {
    errorLogger(error, { context: 'Health check' });

    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: 'Health check failed',
      message: error.message,
    });
  }
});

/**
 * @route   GET /api/v1/health/database
 * @desc    데이터베이스 상세 헬스체크
 * @access  Public
 */
router.get('/database', async (req, res) => {
  try {
    const startTime = Date.now();

    // 데이터베이스 연결 및 간단한 쿼리 테스트
    const dbConnected = await checkConnection();

    if (!dbConnected) {
      return res.status(503).json({
        status: 'error',
        message: 'Database connection failed',
        timestamp: new Date().toISOString(),
      });
    }

    // 흡연구역 개수 확인
    const { query } = require('../config/database');
    const result = await query('SELECT COUNT(*) as count FROM smoking_areas WHERE status = $1', ['active']);
    const smokingAreasCount = parseInt(result.rows[0].count);

    const dbHealth = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      connection: {
        status: 'connected',
        pool_stats: getConnectionStats(),
      },
      data: {
        smoking_areas_count: smokingAreasCount,
      },
      response_time: Date.now() - startTime,
    };

    debugLogger('Database health check performed', {
      smokingAreasCount,
      responseTime: dbHealth.response_time,
    });

    res.json(dbHealth);

  } catch (error) {
    errorLogger(error, { context: 'Database health check' });

    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: 'Database health check failed',
      message: error.message,
    });
  }
});

module.exports = router;