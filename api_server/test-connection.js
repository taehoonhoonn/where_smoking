// PostgreSQL 연결 테스트 스크립트
require('dotenv').config();
const { Pool } = require('pg');

async function testConnection() {
  console.log('🔍 PostgreSQL 연결 테스트 시작...');
  console.log('설정:');
  console.log(`  Host: ${process.env.DB_HOST}`);
  console.log(`  Port: ${process.env.DB_PORT}`);
  console.log(`  Database: ${process.env.DB_NAME}`);
  console.log(`  User: ${process.env.DB_USER}`);
  console.log(`  Password: ${process.env.DB_PASSWORD ? '***' : 'null'}`);

  const pool = new Pool({
    host: process.env.DB_HOST.replace(/"/g, ''),
    port: parseInt(process.env.DB_PORT.replace(/"/g, '')),
    database: process.env.DB_NAME.replace(/"/g, ''),
    user: process.env.DB_USER.replace(/"/g, ''),
    password: process.env.DB_PASSWORD.replace(/"/g, ''),
  });

  try {
    const client = await pool.connect();
    console.log('✅ PostgreSQL 연결 성공!');

    const result = await client.query('SELECT NOW()');
    console.log(`📅 현재 시간: ${result.rows[0].now}`);

    // 테이블 존재 확인
    const tableCheck = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'smoking_areas'
      )
    `);

    if (tableCheck.rows[0].exists) {
      console.log('✅ smoking_areas 테이블 존재');

      const countResult = await client.query('SELECT COUNT(*) FROM smoking_areas');
      console.log(`📊 흡연구역 개수: ${countResult.rows[0].count}개`);
    } else {
      console.log('❌ smoking_areas 테이블이 존재하지 않음');
    }

    client.release();
    await pool.end();

  } catch (error) {
    console.error('❌ 연결 실패:', error.message);

    if (error.code === 'ECONNREFUSED') {
      console.log('\n💡 해결 방법:');
      console.log('1. PostgreSQL 서비스 시작:');
      console.log('   sudo service postgresql start');
      console.log('2. 또는 Windows PowerShell(관리자)에서:');
      console.log('   wsl -d Ubuntu -u root service postgresql start');
    }
  }
}

testConnection();