const { Pool } = require('pg');
const { sqlLogger, errorLogger, debugLogger } = require('./logger');

// PostgreSQL 연결 풀 생성
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'smoking_areas_db',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  max: 20, // 최대 연결 수
  idleTimeoutMillis: 30000, // 유휴 연결 제거 시간
  connectionTimeoutMillis: 2000, // 연결 타임아웃
});

// 연결 테스트
pool.on('connect', (client) => {
  debugLogger('New database connection established');
});

pool.on('error', (err) => {
  errorLogger(err, { context: 'Database connection pool' });
});

// 쿼리 실행 함수
const query = async (text, params = []) => {
  const start = Date.now();

  try {
    sqlLogger(text, params);

    const result = await pool.query(text, params);
    const duration = Date.now() - start;

    debugLogger('Query executed successfully', {
      duration: `${duration}ms`,
      rows: result.rowCount,
    });

    return result;
  } catch (error) {
    const duration = Date.now() - start;

    errorLogger(error, {
      context: 'Database query execution',
      query: text,
      params,
      duration: `${duration}ms`,
    });

    throw error;
  }
};

// 트랜잭션 실행 함수
const transaction = async (callback) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    debugLogger('Transaction started');

    const result = await callback(client);

    await client.query('COMMIT');
    debugLogger('Transaction committed');

    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    errorLogger(error, { context: 'Transaction rollback' });
    throw error;
  } finally {
    client.release();
  }
};

// 데이터베이스 연결 확인
const checkConnection = async () => {
  try {
    await query('SELECT NOW()');
    debugLogger('Database connection test successful');
    return true;
  } catch (error) {
    errorLogger(error, { context: 'Database connection test' });
    return false;
  }
};

// 헬스체크용 통계
const getConnectionStats = () => {
  return {
    totalCount: pool.totalCount,
    idleCount: pool.idleCount,
    waitingCount: pool.waitingCount,
  };
};

module.exports = {
  pool,
  query,
  transaction,
  checkConnection,
  getConnectionStats,
};