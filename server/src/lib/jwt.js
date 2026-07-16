const jwt = require('jsonwebtoken');

function signAdminToken(admin) {
  return jwt.sign({ sub: admin.id, email: admin.email }, process.env.JWT_SECRET, {
    expiresIn: '7d',
  });
}

function verifyToken(token) {
  return jwt.verify(token, process.env.JWT_SECRET);
}

module.exports = { signAdminToken, verifyToken };
