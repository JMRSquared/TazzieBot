"use strict";

var _mongoose = require("mongoose");

var _mongoose2 = _interopRequireDefault(_mongoose);

var _UserController = require("./routes/UserController");

var _UserController2 = _interopRequireDefault(_UserController);

var _AccountController = require("./routes/AccountController");

var _AccountController2 = _interopRequireDefault(_AccountController);

var _SignalController = require("./routes/SignalController");

var _SignalController2 = _interopRequireDefault(_SignalController);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var express = require("express");
var path = require("path");
var favicon = require("static-favicon");
var logger = require("morgan");
var cookieParser = require("cookie-parser");
var bodyParser = require("body-parser");

var app = express();

// view engine setup
app.set("views", path.join(__dirname, "views"));
app.set("view engine", "jade");

app.use(favicon());
app.use(logger("dev"));
app.use(bodyParser.json({
    limit: "50mb"
}));
app.use(bodyParser.urlencoded({
    limit: "50mb"
}));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, "public")));
app.use(function (req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    next();
});

_mongoose2.default.connect("mongodb://localhost:27017/TazzieDB?authSource=admin", {
    auth: {
        user: "admin",
        password: "Mulavhelesi@1"
    },
    useNewUrlParser: true,
    reconnectTries: Number.MAX_VALUE, // Never stop trying to reconnect
    reconnectInterval: 500, // Reconnect every 500ms
    dbName: "TazzieDB"
}).then(function (answer) {
    console.log("Successfully connected to MONGO!");
});

app.use("/u", _UserController2.default);
app.use("/acc", _AccountController2.default);
app.use("/s", _SignalController2.default);

/// catch 404 and forwarding to error handler
app.use(function (req, res, next) {
    var err = new Error("Not Found");
    err.status = 404;
    next(err);
});

/// error handlers

// development error handler
// will print stacktrace
if (app.get("env") === "development") {
    app.use(function (err, req, res, next) {
        res.status(err.status || 500);
        res.render("error", {
            message: err.message,
            error: err
        });
    });
}

// production error handler
// no stacktraces leaked to user
app.use(function (err, req, res, next) {
    res.status(err.status || 500);
    res.render("error", {
        message: err.message,
        error: {}
    });
});

module.exports = app;