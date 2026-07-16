// Wraps an async route handler so a rejected promise reaches Express's error
// handler instead of crashing the process silently.
function asyncRoute(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  // Prisma "record to update/delete does not exist" -> 404, not 500.
  if (err && err.code === 'P2025') {
    return res.status(404).json({ error: 'Not found' });
  }
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
}

module.exports = { asyncRoute, errorHandler };
