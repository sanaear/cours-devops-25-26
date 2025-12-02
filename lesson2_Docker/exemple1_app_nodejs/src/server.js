const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send(`
    <h1>Welcome to my awesome app!</h1>
    <h2>sana achour</h2>
    <img src="https://i.pinimg.com/originals/cb/22/60/cb22603604e36d1caab7cc4e729506c9.gif" alt="Beautiful Landscape" style="max-width:400px;">
  `);
});

app.listen(8088, function () {
  console.log("app listening on port 8088, go to http://localhost:8088");
});
