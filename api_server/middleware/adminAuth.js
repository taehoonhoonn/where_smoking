const { debugLogger } = require('../config/logger');

const normalizeToken = (value) => {
  if (!value) return null;
  const trimmed = value.trim();
  if (trimmed.toLowerCase().startsWith('bearer ')) {
    return trimmed.slice(7).trim();
  }
  return trimmed;
};

module.exports = (req, res, next) => {
  const adminToken = process.env.ADMIN_ACCESS_TOKEN;

  if (!adminToken) {
    debugLogger('ADMIN_ACCESS_TOKEN not set; skipping admin auth', {
      path: req.originalUrl,
    });
    return next();
  }

  const provided = normalizeToken(
    req.get('x-admin-token') || req.get('X-Admin-Token') || req.get('authorization'),
  );

  if (!provided || provided !== adminToken) {
    debugLogger('Admin authorization failed', {
      path: req.originalUrl,
      method: req.method,
      hasHeader: Boolean(provided),
    });

    return res.status(403).json({
      success: false,
      error: 'Forbidden',
      message: '관리자 권한이 필요합니다.',
    });
  }

  return next();
};
