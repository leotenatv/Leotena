require('dotenv').config();

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const { errorHandler } = require('./middleware/errorHandler');

const app = express();

app.use(cors({ origin: true, credentials: false }));
app.use(express.json());
app.use(morgan('dev'));

app.use(require('./routes/health.routes'));
app.use(require('./routes/auth.routes'));
app.use(require('./routes/settings.routes'));
app.use(require('./routes/channels.routes'));
app.use(require('./routes/schedule.routes'));
app.use(require('./routes/carousel.routes'));
app.use(require('./routes/pricing.routes'));
app.use(require('./routes/devices.routes'));
app.use(require('./routes/subscriptions.routes'));
app.use(require('./routes/notifications.routes'));
app.use(require('./routes/payments.routes'));

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use(errorHandler);

const port = process.env.PORT || 4000;
app.listen(port, () => {
  console.log(`leotena-server listening on :${port}`);
});
