// Generated from the reference sketch runtime sources.

///|
let sketch_runtime_source : String =
  #|function _array_like_to_array(arr, len) {
  #|    if (len == null || len > arr.length) len = arr.length;
  #|    for(var i = 0, arr2 = new Array(len); i < len; i++)arr2[i] = arr[i];
  #|    return arr2;
  #|}
  #|function _array_with_holes(arr) {
  #|    if (Array.isArray(arr)) return arr;
  #|}
  #|function _array_without_holes(arr) {
  #|    if (Array.isArray(arr)) return _array_like_to_array(arr);
  #|}
  #|function _assert_this_initialized(self1) {
  #|    if (self1 === void 0) {
  #|        throw new ReferenceError("this hasn't been initialised - super() hasn't been called");
  #|    }
  #|    return self1;
  #|}
  #|function _call_super(_this, derived, args) {
  #|    derived = _get_prototype_of(derived);
  #|    return _possible_constructor_return(_this, _is_native_reflect_construct() ? Reflect.construct(derived, args || [], _get_prototype_of(_this).constructor) : derived.apply(_this, args));
  #|}
  #|function _class_call_check(instance, Constructor) {
  #|    if (!(instance instanceof Constructor)) {
  #|        throw new TypeError("Cannot call a class as a function");
  #|    }
  #|}
  #|function _defineProperties(target, props) {
  #|    for(var i = 0; i < props.length; i++){
  #|        var descriptor = props[i];
  #|        descriptor.enumerable = descriptor.enumerable || false;
  #|        descriptor.configurable = true;
  #|        if ("value" in descriptor) descriptor.writable = true;
  #|        Object.defineProperty(target, descriptor.key, descriptor);
  #|    }
  #|}
  #|function _create_class(Constructor, protoProps, staticProps) {
  #|    if (protoProps) _defineProperties(Constructor.prototype, protoProps);
  #|    if (staticProps) _defineProperties(Constructor, staticProps);
  #|    return Constructor;
  #|}
  #|function _get_prototype_of(o) {
  #|    _get_prototype_of = Object.setPrototypeOf ? Object.getPrototypeOf : function getPrototypeOf(o) {
  #|        return o.__proto__ || Object.getPrototypeOf(o);
  #|    };
  #|    return _get_prototype_of(o);
  #|}
  #|function _inherits(subClass, superClass) {
  #|    if (typeof superClass !== "function" && superClass !== null) {
  #|        throw new TypeError("Super expression must either be null or a function");
  #|    }
  #|    subClass.prototype = Object.create(superClass && superClass.prototype, {
  #|        constructor: {
  #|            value: subClass,
  #|            writable: true,
  #|            configurable: true
  #|        }
  #|    });
  #|    if (superClass) _set_prototype_of(subClass, superClass);
  #|}
  #|function _iterable_to_array(iter) {
  #|    if (typeof Symbol !== "undefined" && iter[Symbol.iterator] != null || iter["@@iterator"] != null) return Array.from(iter);
  #|}
  #|function _iterable_to_array_limit(arr, i) {
  #|    var _i = arr == null ? null : typeof Symbol !== "undefined" && arr[Symbol.iterator] || arr["@@iterator"];
  #|    if (_i == null) return;
  #|    var _arr = [];
  #|    var _n = true;
  #|    var _d = false;
  #|    var _s, _e;
  #|    try {
  #|        for(_i = _i.call(arr); !(_n = (_s = _i.next()).done); _n = true){
  #|            _arr.push(_s.value);
  #|            if (i && _arr.length === i) break;
  #|        }
  #|    } catch (err) {
  #|        _d = true;
  #|        _e = err;
  #|    } finally{
  #|        try {
  #|            if (!_n && _i["return"] != null) _i["return"]();
  #|        } finally{
  #|            if (_d) throw _e;
  #|        }
  #|    }
  #|    return _arr;
  #|}
  #|function _non_iterable_rest() {
  #|    throw new TypeError("Invalid attempt to destructure non-iterable instance.\\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.");
  #|}
  #|function _non_iterable_spread() {
  #|    throw new TypeError("Invalid attempt to spread non-iterable instance.\\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method.");
  #|}
  #|function _possible_constructor_return(self1, call) {
  #|    if (call && (_type_of(call) === "object" || typeof call === "function")) {
  #|        return call;
  #|    }
  #|    return _assert_this_initialized(self1);
  #|}
  #|function _set_prototype_of(o, p) {
  #|    _set_prototype_of = Object.setPrototypeOf || function setPrototypeOf(o, p) {
  #|        o.__proto__ = p;
  #|        return o;
  #|    };
  #|    return _set_prototype_of(o, p);
  #|}
  #|function _sliced_to_array(arr, i) {
  #|    return _array_with_holes(arr) || _iterable_to_array_limit(arr, i) || _unsupported_iterable_to_array(arr, i) || _non_iterable_rest();
  #|}
  #|function _to_consumable_array(arr) {
  #|    return _array_without_holes(arr) || _iterable_to_array(arr) || _unsupported_iterable_to_array(arr) || _non_iterable_spread();
  #|}
  #|function _type_of(obj) {
  #|    "@swc/helpers - typeof";
  #|    return obj && typeof Symbol !== "undefined" && obj.constructor === Symbol ? "symbol" : typeof obj;
  #|}
  #|function _unsupported_iterable_to_array(o, minLen) {
  #|    if (!o) return;
  #|    if (typeof o === "string") return _array_like_to_array(o, minLen);
  #|    var n = Object.prototype.toString.call(o).slice(8, -1);
  #|    if (n === "Object" && o.constructor) n = o.constructor.name;
  #|    if (n === "Map" || n === "Set") return Array.from(n);
  #|    if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _array_like_to_array(o, minLen);
  #|}
  #|function _is_native_reflect_construct() {
  #|    try {
  #|        var result = !Boolean.prototype.valueOf.call(Reflect.construct(Boolean, [], function() {}));
  #|    } catch (_) {}
  #|    return (_is_native_reflect_construct = function() {
  #|        return !!result;
  #|    })();
  #|}
  #|/*eslint-disable */ // This is a slightly modified version of rough.js for this project
  #|//
  #|// rough.js is from https://github.com/rough-stuff/rough.
  #|// Attribution for this file is as follows:
  #|//
  #|// MIT License
  #|//
  #|// Copyright (c) 2019 Preet Shihn
  #|//
  #|// Permission is hereby granted, free of charge, to any person obtaining a copy
  #|// of this software and associated documentation files (the "Software"), to deal
  #|// in the Software without restriction, including without limitation the rights
  #|// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  #|// copies of the Software, and to permit persons to whom the Software is
  #|// furnished to do so, subject to the following conditions:
  #|//
  #|// The above copyright notice and this permission notice shall be included in all
  #|// copies or substantial portions of the Software.
  #|//
  #|// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  #|// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  #|// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  #|// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  #|// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  #|// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  #|// SOFTWARE.
  #|//
  #|var t = "http://www.w3.org/2000/svg";
  #|function e(t, e, s) {
  #|    if (t && t.length) {
  #|        var _e = _sliced_to_array(e, 2), n = _e[0], i = _e[1], a = Math.PI / 180 * s, o = Math.cos(a), h = Math.sin(a);
  #|        t.forEach(function(t) {
  #|            var _t = _sliced_to_array(t, 2), _$e = _t[0], _$s = _t[1];
  #|            t[0] = (_$e - n) * o - (_$s - i) * h + n, t[1] = (_$e - n) * h + (_$s - i) * o + i;
  #|        });
  #|    }
  #|}
  #|function s(t) {
  #|    var e = t[0], s = t[1];
  #|    return Math.sqrt(Math.pow(e[0] - s[0], 2) + Math.pow(e[1] - s[1], 2));
  #|}
  #|function n(t, e) {
  #|    return t.type === e;
  #|}
  #|var i = {
  #|    A: 7,
  #|    a: 7,
  #|    C: 6,
  #|    c: 6,
  #|    H: 1,
  #|    h: 1,
  #|    L: 2,
  #|    l: 2,
  #|    M: 2,
  #|    m: 2,
  #|    Q: 4,
  #|    q: 4,
  #|    S: 4,
  #|    s: 4,
  #|    T: 4,
  #|    t: 2,
  #|    V: 1,
  #|    v: 1,
  #|    Z: 0,
  #|    z: 0
  #|};
  #|var a = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function a(t) {
  #|        _class_call_check(this, a);
  #|        this.COMMAND = 0, this.NUMBER = 1, this.EOD = 2, this.segments = [], this.parseData(t), this.processPoints();
  #|    }
  #|    _create_class(a, [
  #|        {
  #|            key: "tokenize",
  #|            value: function tokenize(t) {
  #|                var e = new Array();
  #|                for(; "" !== t;){
  #|                    var _$a = t.match(/^([ \t\r\n,]+)/);
  #|                    var b = t.match(/^([aAcChHlLmMqQsStTvVzZ])/);
  #|                    var c = t.match(/^(([-+]?[0-9]+(\.[0-9]*)?|[-+]?\.[0-9]+)([eE][-+]?[0-9]+)?)/);
  #|                    if (_$a) t = t.slice(_$a[0].length);
  #|                    else if (b) e[e.length] = {
  #|                        type: this.COMMAND,
  #|                        text: b[0]
  #|                    }, t = t.slice(b[0].length);
  #|                    else {
  #|                        if (!c) return [];
  #|                        e[e.length] = {
  #|                            type: this.NUMBER,
  #|                            text: "".concat(parseFloat(c[0]))
  #|                        }, t = t.slice(c[0].length);
  #|                    }
  #|                }
  #|                return e[e.length] = {
  #|                    type: this.EOD,
  #|                    text: ""
  #|                }, e;
  #|            }
  #|        },
  #|        {
  #|            key: "parseData",
  #|            value: function parseData(t) {
  #|                var e = this.tokenize(t);
  #|                var s = 0, _$a = e[s], o = "BOD";
  #|                for(this.segments = new Array(); !n(_$a, this.EOD);){
  #|                    var h = void 0;
  #|                    var r = new Array();
  #|                    if ("BOD" === o) {
  #|                        if ("M" !== _$a.text && "m" !== _$a.text) return void this.parseData("M0,0" + t);
  #|                        s++, h = i[_$a.text], o = _$a.text;
  #|                    } else n(_$a, this.NUMBER) ? h = i[o] : (s++, h = i[_$a.text], o = _$a.text);
  #|                    if (s + h < e.length) {
  #|                        for(var _$t = s; _$t < s + h; _$t++){
  #|                            var s1 = e[_$t];
  #|                            if (!n(s1, this.NUMBER)) return void console.error("Param not a number: " + o + "," + s1.text);
  #|                            r[r.length] = +s1.text;
  #|                        }
  #|                        if ("number" != typeof i[o]) return void console.error("Bad segment: " + o);
  #|                        {
  #|                            var _$t1 = {
  #|                                key: o,
  #|                                data: r
  #|                            };
  #|                            this.segments.push(_$t1), s += h, _$a = e[s], "M" === o && (o = "L"), "m" === o && (o = "l");
  #|                        }
  #|                    } else console.error("Path data ended short");
  #|                }
  #|            }
  #|        },
  #|        {
  #|            key: "closed",
  #|            "get": function _get() {
  #|                if (void 0 === this._closed) {
  #|                    this._closed = !1;
  #|                    var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                    try {
  #|                        for(var _iterator = this.segments[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                            var t = _step.value;
  #|                            "z" === t.key.toLowerCase() && (this._closed = !0);
  #|                        }
  #|                    } catch (err) {
  #|                        _didIteratorError = true;
  #|                        _iteratorError = err;
  #|                    } finally{
  #|                        try {
  #|                            if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                                _iterator.return();
  #|                            }
  #|                        } finally{
  #|                            if (_didIteratorError) {
  #|                                throw _iteratorError;
  #|                            }
  #|                        }
  #|                    }
  #|                }
  #|                return this._closed;
  #|            }
  #|        },
  #|        {
  #|            key: "processPoints",
  #|            value: function processPoints() {
  #|                var t = null, e = [
  #|                    0,
  #|                    0
  #|                ];
  #|                for(var s = 0; s < this.segments.length; s++){
  #|                    var n = this.segments[s];
  #|                    switch(n.key){
  #|                        case "M":
  #|                        case "L":
  #|                        case "T":
  #|                            n.point = [
  #|                                n.data[0],
  #|                                n.data[1]
  #|                            ];
  #|                            break;
  #|                        case "m":
  #|                        case "l":
  #|                        case "t":
  #|                            n.point = [
  #|                                n.data[0] + e[0],
  #|                                n.data[1] + e[1]
  #|                            ];
  #|                            break;
  #|                        case "H":
  #|                            n.point = [
  #|                                n.data[0],
  #|                                e[1]
  #|                            ];
  #|                            break;
  #|                        case "h":
  #|                            n.point = [
  #|                                n.data[0] + e[0],
  #|                                e[1]
  #|                            ];
  #|                            break;
  #|                        case "V":
  #|                            n.point = [
  #|                                e[0],
  #|                                n.data[0]
  #|                            ];
  #|                            break;
  #|                        case "v":
  #|                            n.point = [
  #|                                e[0],
  #|                                n.data[0] + e[1]
  #|                            ];
  #|                            break;
  #|                        case "z":
  #|                        case "Z":
  #|                            t && (n.point = [
  #|                                t[0],
  #|                                t[1]
  #|                            ]);
  #|                            break;
  #|                        case "C":
  #|                            n.point = [
  #|                                n.data[4],
  #|                                n.data[5]
  #|                            ];
  #|                            break;
  #|                        case "c":
  #|                            n.point = [
  #|                                n.data[4] + e[0],
  #|                                n.data[5] + e[1]
  #|                            ];
  #|                            break;
  #|                        case "S":
  #|                            n.point = [
  #|                                n.data[2],
  #|                                n.data[3]
  #|                            ];
  #|                            break;
  #|                        case "s":
  #|                            n.point = [
  #|                                n.data[2] + e[0],
  #|                                n.data[3] + e[1]
  #|                            ];
  #|                            break;
  #|                        case "Q":
  #|                            n.point = [
  #|                                n.data[2],
  #|                                n.data[3]
  #|                            ];
  #|                            break;
  #|                        case "q":
  #|                            n.point = [
  #|                                n.data[2] + e[0],
  #|                                n.data[3] + e[1]
  #|                            ];
  #|                            break;
  #|                        case "A":
  #|                            n.point = [
  #|                                n.data[5],
  #|                                n.data[6]
  #|                            ];
  #|                            break;
  #|                        case "a":
  #|                            n.point = [
  #|                                n.data[5] + e[0],
  #|                                n.data[6] + e[1]
  #|                            ];
  #|                    }
  #|                    "m" !== n.key && "M" !== n.key || (t = null), n.point && (e = n.point, t || (t = n.point)), "z" !== n.key && "Z" !== n.key || (t = null);
  #|                }
  #|            }
  #|        }
  #|    ]);
  #|    return a;
  #|}();
  #|var o = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function o(t) {
  #|        _class_call_check(this, o);
  #|        this._position = [
  #|            0,
  #|            0
  #|        ], this._first = null, this.bezierReflectionPoint = null, this.quadReflectionPoint = null, this.parsed = new a(t);
  #|    }
  #|    _create_class(o, [
  #|        {
  #|            key: "segments",
  #|            "get": function _get() {
  #|                return this.parsed.segments;
  #|            }
  #|        },
  #|        {
  #|            key: "closed",
  #|            "get": function _get() {
  #|                return this.parsed.closed;
  #|            }
  #|        },
  #|        {
  #|            key: "linearPoints",
  #|            "get": function _get() {
  #|                if (!this._linearPoints) {
  #|                    var t = [];
  #|                    var e = [];
  #|                    var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                    try {
  #|                        for(var _iterator = this.parsed.segments[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                            var s = _step.value;
  #|                            var n = s.key.toLowerCase();
  #|                            ("m" !== n && "z" !== n || (e.length && (t.push(e), e = []), "z" !== n)) && s.point && e.push(s.point);
  #|                        }
  #|                    } catch (err) {
  #|                        _didIteratorError = true;
  #|                        _iteratorError = err;
  #|                    } finally{
  #|                        try {
  #|                            if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                                _iterator.return();
  #|                            }
  #|                        } finally{
  #|                            if (_didIteratorError) {
  #|                                throw _iteratorError;
  #|                            }
  #|                        }
  #|                    }
  #|                    e.length && (t.push(e), e = []), this._linearPoints = t;
  #|                }
  #|                return this._linearPoints;
  #|            }
  #|        },
  #|        {
  #|            key: "first",
  #|            "get": function _get() {
  #|                return this._first;
  #|            },
  #|            "set": function _set(t) {
  #|                this._first = t;
  #|            }
  #|        },
  #|        {
  #|            key: "setPosition",
  #|            value: function setPosition(t, e) {
  #|                this._position = [
  #|                    t,
  #|                    e
  #|                ], this._first || (this._first = [
  #|                    t,
  #|                    e
  #|                ]);
  #|            }
  #|        },
  #|        {
  #|            key: "position",
  #|            "get": function _get() {
  #|                return this._position;
  #|            }
  #|        },
  #|        {
  #|            key: "x",
  #|            "get": function _get() {
  #|                return this._position[0];
  #|            }
  #|        },
  #|        {
  #|            key: "y",
  #|            "get": function _get() {
  #|                return this._position[1];
  #|            }
  #|        }
  #|    ]);
  #|    return o;
  #|}();
  #|var h = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function h(t, e, s, n, i, a) {
  #|        _class_call_check(this, h);
  #|        if (this._segIndex = 0, this._numSegs = 0, this._rx = 0, this._ry = 0, this._sinPhi = 0, this._cosPhi = 0, this._C = [
  #|            0,
  #|            0
  #|        ], this._theta = 0, this._delta = 0, this._T = 0, this._from = t, t[0] === e[0] && t[1] === e[1]) return;
  #|        var o = Math.PI / 180;
  #|        this._rx = Math.abs(s[0]), this._ry = Math.abs(s[1]), this._sinPhi = Math.sin(n * o), this._cosPhi = Math.cos(n * o);
  #|        var _$h = this._cosPhi * (t[0] - e[0]) / 2 + this._sinPhi * (t[1] - e[1]) / 2, r = -this._sinPhi * (t[0] - e[0]) / 2 + this._cosPhi * (t[1] - e[1]) / 2;
  #|        var c = 0;
  #|        var l = this._rx * this._rx * this._ry * this._ry - this._rx * this._rx * r * r - this._ry * this._ry * _$h * _$h;
  #|        if (l < 0) {
  #|            var _$t = Math.sqrt(1 - l / (this._rx * this._rx * this._ry * this._ry));
  #|            this._rx = this._rx * _$t, this._ry = this._ry * _$t, c = 0;
  #|        } else c = (i === a ? -1 : 1) * Math.sqrt(l / (this._rx * this._rx * r * r + this._ry * this._ry * _$h * _$h));
  #|        var u = c * this._rx * r / this._ry, p = -c * this._ry * _$h / this._rx;
  #|        this._C = [
  #|            0,
  #|            0
  #|        ], this._C[0] = this._cosPhi * u - this._sinPhi * p + (t[0] + e[0]) / 2, this._C[1] = this._sinPhi * u + this._cosPhi * p + (t[1] + e[1]) / 2, this._theta = this.calculateVectorAngle(1, 0, (_$h - u) / this._rx, (r - p) / this._ry);
  #|        var d = this.calculateVectorAngle((_$h - u) / this._rx, (r - p) / this._ry, (-_$h - u) / this._rx, (-r - p) / this._ry);
  #|        !a && d > 0 ? d -= 2 * Math.PI : a && d < 0 && (d += 2 * Math.PI), this._numSegs = Math.ceil(Math.abs(d / (Math.PI / 2))), this._delta = d / this._numSegs, this._T = 8 / 3 * Math.sin(this._delta / 4) * Math.sin(this._delta / 4) / Math.sin(this._delta / 2);
  #|    }
  #|    _create_class(h, [
  #|        {
  #|            key: "getNextSegment",
  #|            value: function getNextSegment() {
  #|                if (this._segIndex === this._numSegs) return null;
  #|                var t = Math.cos(this._theta), e = Math.sin(this._theta), s = this._theta + this._delta, n = Math.cos(s), i = Math.sin(s), a = [
  #|                    this._cosPhi * this._rx * n - this._sinPhi * this._ry * i + this._C[0],
  #|                    this._sinPhi * this._rx * n + this._cosPhi * this._ry * i + this._C[1]
  #|                ], o = [
  #|                    this._from[0] + this._T * (-this._cosPhi * this._rx * e - this._sinPhi * this._ry * t),
  #|                    this._from[1] + this._T * (-this._sinPhi * this._rx * e + this._cosPhi * this._ry * t)
  #|                ], _$h = [
  #|                    a[0] + this._T * (this._cosPhi * this._rx * i + this._sinPhi * this._ry * n),
  #|                    a[1] + this._T * (this._sinPhi * this._rx * i - this._cosPhi * this._ry * n)
  #|                ];
  #|                return this._theta = s, this._from = [
  #|                    a[0],
  #|                    a[1]
  #|                ], this._segIndex++, {
  #|                    cp1: o,
  #|                    cp2: _$h,
  #|                    to: a
  #|                };
  #|            }
  #|        },
  #|        {
  #|            key: "calculateVectorAngle",
  #|            value: function calculateVectorAngle(t, e, s, n) {
  #|                var i = Math.atan2(e, t), a = Math.atan2(n, s);
  #|                return a >= i ? a - i : 2 * Math.PI - (i - a);
  #|            }
  #|        }
  #|    ]);
  #|    return h;
  #|}();
  #|var r = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function r(t, e) {
  #|        _class_call_check(this, r);
  #|        this.sets = t, this.closed = e;
  #|    }
  #|    _create_class(r, [
  #|        {
  #|            key: "fit",
  #|            value: function fit(t) {
  #|                var e = [];
  #|                var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                try {
  #|                    for(var _iterator = this.sets[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                        var s = _step.value;
  #|                        var n = s.length;
  #|                        var i = Math.floor(t * n);
  #|                        if (i < 5) {
  #|                            if (n <= 5) continue;
  #|                            i = 5;
  #|                        }
  #|                        e.push(this.reduce(s, i));
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError = true;
  #|                    _iteratorError = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                            _iterator.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError) {
  #|                            throw _iteratorError;
  #|                        }
  #|                    }
  #|                }
  #|                var s1 = "";
  #|                var _iteratorNormalCompletion1 = true, _didIteratorError1 = false, _iteratorError1 = undefined;
  #|                try {
  #|                    for(var _iterator1 = e[Symbol.iterator](), _step1; !(_iteratorNormalCompletion1 = (_step1 = _iterator1.next()).done); _iteratorNormalCompletion1 = true){
  #|                        var _$t = _step1.value;
  #|                        for(var e1 = 0; e1 < _$t.length; e1++){
  #|                            var n1 = _$t[e1];
  #|                            s1 += 0 === e1 ? "M" + n1[0] + "," + n1[1] : "L" + n1[0] + "," + n1[1];
  #|                        }
  #|                        this.closed && (s1 += "z ");
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError1 = true;
  #|                    _iteratorError1 = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion1 && _iterator1.return != null) {
  #|                            _iterator1.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError1) {
  #|                            throw _iteratorError1;
  #|                        }
  #|                    }
  #|                }
  #|                return s1;
  #|            }
  #|        },
  #|        {
  #|            key: "reduce",
  #|            value: function reduce(t, e) {
  #|                if (t.length <= e) return t;
  #|                var n = t.slice(0);
  #|                for(; n.length > e;){
  #|                    var _$t = -1, _$e = -1;
  #|                    for(var i = 1; i < n.length - 1; i++){
  #|                        var a = s([
  #|                            n[i - 1],
  #|                            n[i]
  #|                        ]), o = s([
  #|                            n[i],
  #|                            n[i + 1]
  #|                        ]), h = s([
  #|                            n[i - 1],
  #|                            n[i + 1]
  #|                        ]), _$r = (a + o + h) / 2, c = Math.sqrt(_$r * (_$r - a) * (_$r - o) * (_$r - h));
  #|                        (_$t < 0 || c < _$t) && (_$t = c, _$e = i);
  #|                    }
  #|                    if (!(_$e > 0)) break;
  #|                    n.splice(_$e, 1);
  #|                }
  #|                return n;
  #|            }
  #|        }
  #|    ]);
  #|    return r;
  #|}();
  #|function c(t, s) {
  #|    var n = [
  #|        0,
  #|        0
  #|    ], i = Math.round(s.hachureAngle + 90);
  #|    i && e(t, n, i);
  #|    var a = function(t, e) {
  #|        var _$s = _to_consumable_array(t);
  #|        _$s[0].join(",") !== _$s[_$s.length - 1].join(",") && _$s.push([
  #|            _$s[0][0],
  #|            _$s[0][1]
  #|        ]);
  #|        var n = [];
  #|        if (_$s && _$s.length > 2) {
  #|            var _$t = e.hachureGap;
  #|            _$t < 0 && (_$t = 4 * e.strokeWidth), _$t = Math.max(_$t, 0.1);
  #|            var i = [];
  #|            for(var _$t1 = 0; _$t1 < _$s.length - 1; _$t1++){
  #|                var _$e = _$s[_$t1], n1 = _$s[_$t1 + 1];
  #|                if (_$e[1] !== n1[1]) {
  #|                    var _$t2 = Math.min(_$e[1], n1[1]);
  #|                    i.push({
  #|                        ymin: _$t2,
  #|                        ymax: Math.max(_$e[1], n1[1]),
  #|                        x: _$t2 === _$e[1] ? _$e[0] : n1[0],
  #|                        islope: (n1[0] - _$e[0]) / (n1[1] - _$e[1])
  #|                    });
  #|                }
  #|            }
  #|            if (i.sort(function(t, e) {
  #|                return t.ymin < e.ymin ? -1 : t.ymin > e.ymin ? 1 : t.x < e.x ? -1 : t.x > e.x ? 1 : t.ymax === e.ymax ? 0 : (t.ymax - e.ymax) / Math.abs(t.ymax - e.ymax);
  #|            }), !i.length) return n;
  #|            var a = [], o = i[0].ymin;
  #|            for(; a.length || i.length;){
  #|                if (i.length) {
  #|                    var _$t3 = -1;
  #|                    for(var _$e1 = 0; _$e1 < i.length && !(i[_$e1].ymin > o); _$e1++)_$t3 = _$e1;
  #|                    i.splice(0, _$t3 + 1).forEach(function(t) {
  #|                        a.push({
  #|                            s: o,
  #|                            edge: t
  #|                        });
  #|                    });
  #|                }
  #|                if (a = a.filter(function(t) {
  #|                    return !(t.edge.ymax <= o);
  #|                }), a.sort(function(t, e) {
  #|                    return t.edge.x === e.edge.x ? 0 : (t.edge.x - e.edge.x) / Math.abs(t.edge.x - e.edge.x);
  #|                }), a.length > 1) for(var _$t4 = 0; _$t4 < a.length; _$t4 += 2){
  #|                    var _$e2 = _$t4 + 1;
  #|                    if (_$e2 >= a.length) break;
  #|                    var _$s1 = a[_$t4].edge, i1 = a[_$e2].edge;
  #|                    n.push([
  #|                        [
  #|                            Math.round(_$s1.x),
  #|                            o
  #|                        ],
  #|                        [
  #|                            Math.round(i1.x),
  #|                            o
  #|                        ]
  #|                    ]);
  #|                }
  #|                o += _$t, a.forEach(function(e) {
  #|                    e.edge.x = e.edge.x + _$t * e.edge.islope;
  #|                });
  #|            }
  #|        }
  #|        return n;
  #|    }(t, s);
  #|    return i && (e(t, n, -i), function(t, s, n) {
  #|        var _i;
  #|        var i = [];
  #|        t.forEach(function(t) {
  #|            return (_i = i).push.apply(_i, _to_consumable_array(t));
  #|        }), e(i, s, n);
  #|    }(a, n, -i)), a;
  #|}
  #|var l = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function l(t) {
  #|        _class_call_check(this, l);
  #|        this.helper = t;
  #|    }
  #|    _create_class(l, [
  #|        {
  #|            key: "fillPolygon",
  #|            value: function fillPolygon(t, e) {
  #|                return this._fillPolygon(t, e);
  #|            }
  #|        },
  #|        {
  #|            key: "_fillPolygon",
  #|            value: function _fillPolygon(t, e) {
  #|                var s = arguments.length > 2 && arguments[2] !== void 0 ? arguments[2] : !1;
  #|                var n = c(t, e);
  #|                return {
  #|                    type: "fillSketch",
  #|                    ops: this.renderLines(n, e, s)
  #|                };
  #|            }
  #|        },
  #|        {
  #|            key: "renderLines",
  #|            value: function renderLines(t, e, s) {
  #|                var n = [], i = null;
  #|                var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                try {
  #|                    for(var _iterator = t[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                        var a = _step.value;
  #|                        n = n.concat(this.helper.doubleLineOps(a[0][0], a[0][1], a[1][0], a[1][1], e)), s && i && (n = n.concat(this.helper.doubleLineOps(i[0], i[1], a[0][0], a[0][1], e))), i = a[1];
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError = true;
  #|                    _iteratorError = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                            _iterator.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError) {
  #|                            throw _iteratorError;
  #|                        }
  #|                    }
  #|                }
  #|                return n;
  #|            }
  #|        }
  #|    ]);
  #|    return l;
  #|}();
  #|var u = /*#__PURE__*/ function(l) {
  #|    "use strict";
  #|    _inherits(u, l);
  #|    function u() {
  #|        _class_call_check(this, u);
  #|        return _call_super(this, u, arguments);
  #|    }
  #|    _create_class(u, [
  #|        {
  #|            key: "fillPolygon",
  #|            value: function fillPolygon(t, e) {
  #|                return this._fillPolygon(t, e, !0);
  #|            }
  #|        }
  #|    ]);
  #|    return u;
  #|}(l);
  #|var p = /*#__PURE__*/ function(l) {
  #|    "use strict";
  #|    _inherits(p, l);
  #|    function p() {
  #|        _class_call_check(this, p);
  #|        return _call_super(this, p, arguments);
  #|    }
  #|    _create_class(p, [
  #|        {
  #|            key: "fillPolygon",
  #|            value: function fillPolygon(t, e) {
  #|                var s = this._fillPolygon(t, e), n = Object.assign({}, e, {
  #|                    hachureAngle: e.hachureAngle + 90
  #|                }), i = this._fillPolygon(t, n);
  #|                return s.ops = s.ops.concat(i.ops), s;
  #|            }
  #|        }
  #|    ]);
  #|    return p;
  #|}(l);
  #|var d = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function d(t) {
  #|        _class_call_check(this, d);
  #|        this.helper = t;
  #|    }
  #|    _create_class(d, [
  #|        {
  #|            key: "fillPolygon",
  #|            value: function fillPolygon(t, e) {
  #|                var s = c(t, e = Object.assign({}, e, {
  #|                    curveStepCount: 4,
  #|                    hachureAngle: 0,
  #|                    roughness: 1
  #|                }));
  #|                return this.dotsOnLines(s, e);
  #|            }
  #|        },
  #|        {
  #|            key: "dotsOnLines",
  #|            value: function dotsOnLines(t, e) {
  #|                var n = [], i = e.hachureGap;
  #|                i < 0 && (i = 4 * e.strokeWidth), i = Math.max(i, 0.1);
  #|                var a = e.fillWeight;
  #|                a < 0 && (a = e.strokeWidth / 2);
  #|                var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                try {
  #|                    for(var _iterator = t[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                        var o = _step.value;
  #|                        var _$t = s(o) / i, h = Math.ceil(_$t) - 1, r = Math.atan((o[1][1] - o[0][1]) / (o[1][0] - o[0][0]));
  #|                        for(var _$t1 = 0; _$t1 < h; _$t1++){
  #|                            var _$s = i * (_$t1 + 1), h1 = _$s * Math.sin(r), c = _$s * Math.cos(r), l = [
  #|                                o[0][0] - c,
  #|                                o[0][1] + h1
  #|                            ], u = this.helper.randOffsetWithRange(l[0] - i / 4, l[0] + i / 4, e), p = this.helper.randOffsetWithRange(l[1] - i / 4, l[1] + i / 4, e), _$d = this.helper.ellipse(u, p, a, a, e);
  #|                            n = n.concat(_$d.ops);
  #|                        }
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError = true;
  #|                    _iteratorError = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                            _iterator.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError) {
  #|                            throw _iteratorError;
  #|                        }
  #|                    }
  #|                }
  #|                return {
  #|                    type: "fillSketch",
  #|                    ops: n
  #|                };
  #|            }
  #|        }
  #|    ]);
  #|    return d;
  #|}();
  #|var f = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function f(t) {
  #|        _class_call_check(this, f);
  #|        this.helper = t;
  #|    }
  #|    _create_class(f, [
  #|        {
  #|            key: "fillPolygon",
  #|            value: function fillPolygon(t, e) {
  #|                var s = c(t, e);
  #|                return {
  #|                    type: "fillSketch",
  #|                    ops: this.dashedLine(s, e)
  #|                };
  #|            }
  #|        },
  #|        {
  #|            key: "dashedLine",
  #|            value: function dashedLine(t, e) {
  #|                var _this = this;
  #|                var n = e.dashOffset < 0 ? e.hachureGap < 0 ? 4 * e.strokeWidth : e.hachureGap : e.dashOffset, i = e.dashGap < 0 ? e.hachureGap < 0 ? 4 * e.strokeWidth : e.hachureGap : e.dashGap;
  #|                var a = [];
  #|                return t.forEach(function(t) {
  #|                    var o = s(t), h = Math.floor(o / (n + i)), r = (o + i - h * (n + i)) / 2;
  #|                    var c = t[0], l = t[1];
  #|                    c[0] > l[0] && (c = t[1], l = t[0]);
  #|                    var u = Math.atan((l[1] - c[1]) / (l[0] - c[0]));
  #|                    for(var _$t = 0; _$t < h; _$t++){
  #|                        var _$s = _$t * (n + i), o1 = _$s + n, h1 = [
  #|                            c[0] + _$s * Math.cos(u) + r * Math.cos(u),
  #|                            c[1] + _$s * Math.sin(u) + r * Math.sin(u)
  #|                        ], l1 = [
  #|                            c[0] + o1 * Math.cos(u) + r * Math.cos(u),
  #|                            c[1] + o1 * Math.sin(u) + r * Math.sin(u)
  #|                        ];
  #|                        a = a.concat(_this.helper.doubleLineOps(h1[0], h1[1], l1[0], l1[1], e));
  #|                    }
  #|                }), a;
  #|            }
  #|        }
  #|    ]);
  #|    return f;
  #|}();
  #|var g = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function g(t) {
  #|        _class_call_check(this, g);
  #|        this.helper = t;
  #|    }
  #|    _create_class(g, [
  #|        {
  #|            key: "fillPolygon",
  #|            value: function fillPolygon(t, e) {
  #|                var s = e.hachureGap < 0 ? 4 * e.strokeWidth : e.hachureGap, n = e.zigzagOffset < 0 ? s : e.zigzagOffset, i = c(t, e = Object.assign({}, e, {
  #|                    hachureGap: s + n
  #|                }));
  #|                return {
  #|                    type: "fillSketch",
  #|                    ops: this.zigzagLines(i, n, e)
  #|                };
  #|            }
  #|        },
  #|        {
  #|            key: "zigzagLines",
  #|            value: function zigzagLines(t, e, n) {
  #|                var _this = this;
  #|                var i = [];
  #|                return t.forEach(function(t) {
  #|                    var a = s(t), o = Math.round(a / (2 * e));
  #|                    var h = t[0], r = t[1];
  #|                    h[0] > r[0] && (h = t[1], r = t[0]);
  #|                    var c = Math.atan((r[1] - h[1]) / (r[0] - h[0]));
  #|                    for(var _$t = 0; _$t < o; _$t++){
  #|                        var _$s = 2 * _$t * e, a1 = 2 * (_$t + 1) * e, o1 = Math.sqrt(2 * Math.pow(e, 2)), r1 = [
  #|                            h[0] + _$s * Math.cos(c),
  #|                            h[1] + _$s * Math.sin(c)
  #|                        ], l = [
  #|                            h[0] + a1 * Math.cos(c),
  #|                            h[1] + a1 * Math.sin(c)
  #|                        ], u = [
  #|                            r1[0] + o1 * Math.cos(c + Math.PI / 4),
  #|                            r1[1] + o1 * Math.sin(c + Math.PI / 4)
  #|                        ];
  #|                        i = i.concat(_this.helper.doubleLineOps(r1[0], r1[1], u[0], u[1], n)), i = i.concat(_this.helper.doubleLineOps(u[0], u[1], l[0], l[1], n));
  #|                    }
  #|                }), i;
  #|            }
  #|        }
  #|    ]);
  #|    return g;
  #|}();
  #|var y = {};
  #|var _ = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function _(t) {
  #|        _class_call_check(this, _);
  #|        this.seed = t;
  #|    }
  #|    _create_class(_, [
  #|        {
  #|            key: "next",
  #|            value: function next() {
  #|                return this.seed ? (Math.pow(2, 31) - 1 & (this.seed = Math.imul(48271, this.seed))) / Math.pow(2, 31) : Math.random();
  #|            }
  #|        }
  #|    ]);
  #|    return _;
  #|}();
  #|var M = {
  #|    randOffset: function randOffset(t, e) {
  #|        return z(t, e);
  #|    },
  #|    randOffsetWithRange: function randOffsetWithRange(t, e, s) {
  #|        return C(t, e, s);
  #|    },
  #|    ellipse: function ellipse(t, e, s, n, i) {
  #|        var a = P(s, n, i);
  #|        return w(t, e, i, a).opset;
  #|    },
  #|    doubleLineOps: function doubleLineOps(t, e, s, n, i) {
  #|        return A(t, e, s, n, i);
  #|    }
  #|};
  #|function x(t, e, s, n, i) {
  #|    return {
  #|        type: "path",
  #|        ops: A(t, e, s, n, i)
  #|    };
  #|}
  #|function m(t, e, s) {
  #|    var n = (t || []).length;
  #|    if (n > 2) {
  #|        var i = [];
  #|        for(var _$e = 0; _$e < n - 1; _$e++)i = i.concat(A(t[_$e][0], t[_$e][1], t[_$e + 1][0], t[_$e + 1][1], s));
  #|        return e && (i = i.concat(A(t[n - 1][0], t[n - 1][1], t[0][0], t[0][1], s))), {
  #|            type: "path",
  #|            ops: i
  #|        };
  #|    }
  #|    return 2 === n ? x(t[0][0], t[0][1], t[1][0], t[1][1], s) : {
  #|        type: "path",
  #|        ops: []
  #|    };
  #|}
  #|function k(t, e, s, n, i) {
  #|    return function(t, e) {
  #|        return m(t, !0, e);
  #|    }([
  #|        [
  #|            t,
  #|            e
  #|        ],
  #|        [
  #|            t + s,
  #|            e
  #|        ],
  #|        [
  #|            t + s,
  #|            e + n
  #|        ],
  #|        [
  #|            t,
  #|            e + n
  #|        ]
  #|    ], i);
  #|}
  #|function b(t, e) {
  #|    var s = W(t, 1 * (1 + 0.2 * e.roughness), e), n = W(t, 1.5 * (1 + 0.22 * e.roughness), e);
  #|    return {
  #|        type: "path",
  #|        ops: s.concat(n)
  #|    };
  #|}
  #|function P(t, e, s) {
  #|    var n = Math.sqrt(2 * Math.PI * Math.sqrt((Math.pow(t / 2, 2) + Math.pow(e / 2, 2)) / 2)), i = Math.max(s.curveStepCount, s.curveStepCount / Math.sqrt(200) * n), a = 2 * Math.PI / i;
  #|    var o = Math.abs(t / 2), h = Math.abs(e / 2);
  #|    var r = 1 - s.curveFitting;
  #|    return o += z(o * r, s), h += z(h * r, s), {
  #|        increment: a,
  #|        rx: o,
  #|        ry: h
  #|    };
  #|}
  #|function w(t, e, s, n) {
  #|    var _D = _sliced_to_array(D(n.increment, t, e, n.rx, n.ry, 1, n.increment * C(0.1, C(0.4, 1, s), s), s), 2), i = _D[0], a = _D[1], _D1 = _sliced_to_array(D(n.increment, t, e, n.rx, n.ry, 1.5, 0, s), 1), o = _D1[0], h = R(i, null, s), r = R(o, null, s);
  #|    return {
  #|        estimatedPoints: a,
  #|        opset: {
  #|            type: "path",
  #|            ops: h.concat(r)
  #|        }
  #|    };
  #|}
  #|function v(t, e, s, n, i, a, o, h, r) {
  #|    var c = t, l = e;
  #|    var u = Math.abs(s / 2), p = Math.abs(n / 2);
  #|    u += z(0.01 * u, r), p += z(0.01 * p, r);
  #|    var d = i, f = a;
  #|    for(; d < 0;)d += 2 * Math.PI, f += 2 * Math.PI;
  #|    f - d > 2 * Math.PI && (d = 0, f = 2 * Math.PI);
  #|    var g = 2 * Math.PI / r.curveStepCount, y = Math.min(g / 2, (f - d) / 2), _ = I(y, c, l, u, p, d, f, 1, r), M = I(y, c, l, u, p, d, f, 1.5, r);
  #|    var x = _.concat(M);
  #|    return o && (h ? (x = x.concat(A(c, l, c + u * Math.cos(d), l + p * Math.sin(d), r)), x = x.concat(A(c, l, c + u * Math.cos(f), l + p * Math.sin(f), r))) : (x.push({
  #|        op: "lineTo",
  #|        data: [
  #|            c,
  #|            l
  #|        ]
  #|    }), x.push({
  #|        op: "lineTo",
  #|        data: [
  #|            c + u * Math.cos(d),
  #|            l + p * Math.sin(d)
  #|        ]
  #|    }))), {
  #|        type: "path",
  #|        ops: x
  #|    };
  #|}
  #|function S(t, e) {
  #|    var s = [];
  #|    if (t.length) {
  #|        var n = e.maxRandomnessOffset || 0, i = t.length;
  #|        if (i > 2) {
  #|            s.push({
  #|                op: "move",
  #|                data: [
  #|                    t[0][0] + z(n, e),
  #|                    t[0][1] + z(n, e)
  #|                ]
  #|            });
  #|            for(var a = 1; a < i; a++)s.push({
  #|                op: "lineTo",
  #|                data: [
  #|                    t[a][0] + z(n, e),
  #|                    t[a][1] + z(n, e)
  #|                ]
  #|            });
  #|        }
  #|    }
  #|    return {
  #|        type: "fillPath",
  #|        ops: s
  #|    };
  #|}
  #|function O(t, e) {
  #|    return (function(t, e) {
  #|        var s = t.fillStyle || "hachure";
  #|        if (!y[s]) switch(s){
  #|            case "zigzag":
  #|                y[s] || (y[s] = new u(e));
  #|                break;
  #|            case "cross-hatch":
  #|                y[s] || (y[s] = new p(e));
  #|                break;
  #|            case "dots":
  #|                y[s] || (y[s] = new d(e));
  #|                break;
  #|            case "dashed":
  #|                y[s] || (y[s] = new f(e));
  #|                break;
  #|            case "zigzag-line":
  #|                y[s] || (y[s] = new g(e));
  #|                break;
  #|            case "hachure":
  #|            default:
  #|                s = "hachure", y[s] || (y[s] = new l(e));
  #|        }
  #|        return y[s];
  #|    })(e, M).fillPolygon(t, e);
  #|}
  #|function T(t) {
  #|    return t.randomizer || (t.randomizer = new _(t.seed || 0)), t.randomizer.next();
  #|}
  #|function C(t, e, s) {
  #|    return s.roughness * s.roughnessGain * (T(s) * (e - t) + t);
  #|}
  #|function z(t, e) {
  #|    return C(-t, t, e);
  #|}
  #|function A(t, e, s, n, i) {
  #|    var a = E(t, e, s, n, i, !0, !1), o = E(t, e, s, n, i, !0, !0);
  #|    return a.concat(o);
  #|}
  #|function E(t, e, s, n, i, a, o) {
  #|    var h = Math.pow(t - s, 2) + Math.pow(e - n, 2), r = Math.sqrt(h);
  #|    i.roughnessGain = r < 200 ? 1 : r > 500 ? 0.4 : -0.0016668 * r + 1.233334;
  #|    var c = i.maxRandomnessOffset || 0;
  #|    c * c * 100 > h && (c = r / 10);
  #|    var l = c / 2, u = 0.2 + 0.2 * T(i);
  #|    var p = i.bowing * i.maxRandomnessOffset * (n - e) / 200, d = i.bowing * i.maxRandomnessOffset * (t - s) / 200;
  #|    p = z(p, i), d = z(d, i);
  #|    var f = [], g = function g() {
  #|        return z(l, i);
  #|    }, y = function y() {
  #|        return z(c, i);
  #|    };
  #|    return a && (o ? f.push({
  #|        op: "move",
  #|        data: [
  #|            t + g(),
  #|            e + g()
  #|        ]
  #|    }) : f.push({
  #|        op: "move",
  #|        data: [
  #|            t + z(c, i),
  #|            e + z(c, i)
  #|        ]
  #|    })), o ? f.push({
  #|        op: "bcurveTo",
  #|        data: [
  #|            p + t + (s - t) * u + g(),
  #|            d + e + (n - e) * u + g(),
  #|            p + t + 2 * (s - t) * u + g(),
  #|            d + e + 2 * (n - e) * u + g(),
  #|            s + g(),
  #|            n + g()
  #|        ]
  #|    }) : f.push({
  #|        op: "bcurveTo",
  #|        data: [
  #|            p + t + (s - t) * u + y(),
  #|            d + e + (n - e) * u + y(),
  #|            p + t + 2 * (s - t) * u + y(),
  #|            d + e + 2 * (n - e) * u + y(),
  #|            s + y(),
  #|            n + y()
  #|        ]
  #|    }), f;
  #|}
  #|function W(t, e, s) {
  #|    var n = [];
  #|    n.push([
  #|        t[0][0] + z(e, s),
  #|        t[0][1] + z(e, s)
  #|    ]), n.push([
  #|        t[0][0] + z(e, s),
  #|        t[0][1] + z(e, s)
  #|    ]);
  #|    for(var i = 1; i < t.length; i++)n.push([
  #|        t[i][0] + z(e, s),
  #|        t[i][1] + z(e, s)
  #|    ]), i === t.length - 1 && n.push([
  #|        t[i][0] + z(e, s),
  #|        t[i][1] + z(e, s)
  #|    ]);
  #|    return R(n, null, s);
  #|}
  #|function R(t, e, s) {
  #|    var n = t.length;
  #|    var i = [];
  #|    if (n > 3) {
  #|        var a = [], o = 1 - s.curveTightness;
  #|        i.push({
  #|            op: "move",
  #|            data: [
  #|                t[1][0],
  #|                t[1][1]
  #|            ]
  #|        });
  #|        for(var _$e = 1; _$e + 2 < n; _$e++){
  #|            var _$s = t[_$e];
  #|            a[0] = [
  #|                _$s[0],
  #|                _$s[1]
  #|            ], a[1] = [
  #|                _$s[0] + (o * t[_$e + 1][0] - o * t[_$e - 1][0]) / 6,
  #|                _$s[1] + (o * t[_$e + 1][1] - o * t[_$e - 1][1]) / 6
  #|            ], a[2] = [
  #|                t[_$e + 1][0] + (o * t[_$e][0] - o * t[_$e + 2][0]) / 6,
  #|                t[_$e + 1][1] + (o * t[_$e][1] - o * t[_$e + 2][1]) / 6
  #|            ], a[3] = [
  #|                t[_$e + 1][0],
  #|                t[_$e + 1][1]
  #|            ], i.push({
  #|                op: "bcurveTo",
  #|                data: [
  #|                    a[1][0],
  #|                    a[1][1],
  #|                    a[2][0],
  #|                    a[2][1],
  #|                    a[3][0],
  #|                    a[3][1]
  #|                ]
  #|            });
  #|        }
  #|        if (e && 2 === e.length) {
  #|            var _$t = s.maxRandomnessOffset;
  #|            i.push({
  #|                op: "lineTo",
  #|                data: [
  #|                    e[0] + z(_$t, s),
  #|                    e[1] + z(_$t, s)
  #|                ]
  #|            });
  #|        }
  #|    } else 3 === n ? (i.push({
  #|        op: "move",
  #|        data: [
  #|            t[1][0],
  #|            t[1][1]
  #|        ]
  #|    }), i.push({
  #|        op: "bcurveTo",
  #|        data: [
  #|            t[1][0],
  #|            t[1][1],
  #|            t[2][0],
  #|            t[2][1],
  #|            t[2][0],
  #|            t[2][1]
  #|        ]
  #|    })) : 2 === n && (i = i.concat(A(t[0][0], t[0][1], t[1][0], t[1][1], s)));
  #|    return i;
  #|}
  #|function D(t, e, s, n, i, a, o, h) {
  #|    var r = [], c = [], l = z(0.5, h) - Math.PI / 2;
  #|    c.push([
  #|        z(a, h) + e + 0.9 * n * Math.cos(l - t),
  #|        z(a, h) + s + 0.9 * i * Math.sin(l - t)
  #|    ]);
  #|    for(var _$o = l; _$o < 2 * Math.PI + l - 0.01; _$o += t){
  #|        var _$t = [
  #|            z(a, h) + e + n * Math.cos(_$o),
  #|            z(a, h) + s + i * Math.sin(_$o)
  #|        ];
  #|        r.push(_$t), c.push(_$t);
  #|    }
  #|    return c.push([
  #|        z(a, h) + e + n * Math.cos(l + 2 * Math.PI + 0.5 * o),
  #|        z(a, h) + s + i * Math.sin(l + 2 * Math.PI + 0.5 * o)
  #|    ]), c.push([
  #|        z(a, h) + e + 0.98 * n * Math.cos(l + o),
  #|        z(a, h) + s + 0.98 * i * Math.sin(l + o)
  #|    ]), c.push([
  #|        z(a, h) + e + 0.9 * n * Math.cos(l + 0.5 * o),
  #|        z(a, h) + s + 0.9 * i * Math.sin(l + 0.5 * o)
  #|    ]), [
  #|        c,
  #|        r
  #|    ];
  #|}
  #|function I(t, e, s, n, i, a, o, h, r) {
  #|    var c = a + z(0.1, r), l = [];
  #|    l.push([
  #|        z(h, r) + e + 0.9 * n * Math.cos(c - t),
  #|        z(h, r) + s + 0.9 * i * Math.sin(c - t)
  #|    ]);
  #|    for(var _$a = c; _$a <= o; _$a += t)l.push([
  #|        z(h, r) + e + n * Math.cos(_$a),
  #|        z(h, r) + s + i * Math.sin(_$a)
  #|    ]);
  #|    return l.push([
  #|        e + n * Math.cos(o),
  #|        s + i * Math.sin(o)
  #|    ]), l.push([
  #|        e + n * Math.cos(o),
  #|        s + i * Math.sin(o)
  #|    ]), R(l, null, r);
  #|}
  #|function q(t, e, s, n, i, a, o, h) {
  #|    var r = [], c = [
  #|        h.maxRandomnessOffset || 1,
  #|        (h.maxRandomnessOffset || 1) + 0.5
  #|    ];
  #|    var l = [
  #|        0,
  #|        0
  #|    ];
  #|    for(var u = 0; u < 2; u++)0 === u ? r.push({
  #|        op: "move",
  #|        data: [
  #|            o.x,
  #|            o.y
  #|        ]
  #|    }) : r.push({
  #|        op: "move",
  #|        data: [
  #|            o.x + z(c[0], h),
  #|            o.y + z(c[0], h)
  #|        ]
  #|    }), l = [
  #|        i + z(c[u], h),
  #|        a + z(c[u], h)
  #|    ], r.push({
  #|        op: "bcurveTo",
  #|        data: [
  #|            t + z(c[u], h),
  #|            e + z(c[u], h),
  #|            s + z(c[u], h),
  #|            n + z(c[u], h),
  #|            l[0],
  #|            l[1]
  #|        ]
  #|    });
  #|    return o.setPosition(l[0], l[1]), r;
  #|}
  #|function $(t, e, s, n) {
  #|    var i = [];
  #|    switch(e.key){
  #|        case "M":
  #|        case "m":
  #|            {
  #|                var _$s = "m" === e.key;
  #|                if (e.data.length >= 2) {
  #|                    var a = +e.data[0], o = +e.data[1];
  #|                    _$s && (a += t.x, o += t.y);
  #|                    var h1 = 1 * (n.maxRandomnessOffset || 0);
  #|                    a += z(h1, n), o += z(h1, n), t.setPosition(a, o), i.push({
  #|                        op: "move",
  #|                        data: [
  #|                            a,
  #|                            o
  #|                        ]
  #|                    });
  #|                }
  #|                break;
  #|            }
  #|        case "L":
  #|        case "l":
  #|            {
  #|                var _$s1 = "l" === e.key;
  #|                if (e.data.length >= 2) {
  #|                    var a1 = +e.data[0], o1 = +e.data[1];
  #|                    _$s1 && (a1 += t.x, o1 += t.y), i = i.concat(A(t.x, t.y, a1, o1, n)), t.setPosition(a1, o1);
  #|                }
  #|                break;
  #|            }
  #|        case "H":
  #|        case "h":
  #|            {
  #|                var _$s2 = "h" === e.key;
  #|                if (e.data.length) {
  #|                    var a2 = +e.data[0];
  #|                    _$s2 && (a2 += t.x), i = i.concat(A(t.x, t.y, a2, t.y, n)), t.setPosition(a2, t.y);
  #|                }
  #|                break;
  #|            }
  #|        case "V":
  #|        case "v":
  #|            {
  #|                var _$s3 = "v" === e.key;
  #|                if (e.data.length) {
  #|                    var a3 = +e.data[0];
  #|                    _$s3 && (a3 += t.y), i = i.concat(A(t.x, t.y, t.x, a3, n)), t.setPosition(t.x, a3);
  #|                }
  #|                break;
  #|            }
  #|        case "Z":
  #|        case "z":
  #|            t.first && (i = i.concat(A(t.x, t.y, t.first[0], t.first[1], n)), t.setPosition(t.first[0], t.first[1]), t.first = null);
  #|            break;
  #|        case "C":
  #|        case "c":
  #|            {
  #|                var _$s4 = "c" === e.key;
  #|                if (e.data.length >= 6) {
  #|                    var a4 = +e.data[0], o2 = +e.data[1], h2 = +e.data[2], r = +e.data[3], c = +e.data[4], l = +e.data[5];
  #|                    _$s4 && (a4 += t.x, h2 += t.x, c += t.x, o2 += t.y, r += t.y, l += t.y);
  #|                    var u = q(a4, o2, h2, r, c, l, t, n);
  #|                    i = i.concat(u), t.bezierReflectionPoint = [
  #|                        c + (c - h2),
  #|                        l + (l - r)
  #|                    ];
  #|                }
  #|                break;
  #|            }
  #|        case "S":
  #|        case "s":
  #|            {
  #|                var a5 = "s" === e.key;
  #|                if (e.data.length >= 4) {
  #|                    var o3 = +e.data[0], h3 = +e.data[1], r1 = +e.data[2], c1 = +e.data[3];
  #|                    a5 && (o3 += t.x, r1 += t.x, h3 += t.y, c1 += t.y);
  #|                    var l1 = o3, u1 = h3;
  #|                    var p = s ? s.key : "";
  #|                    var d = null;
  #|                    "c" !== p && "C" !== p && "s" !== p && "S" !== p || (d = t.bezierReflectionPoint), d && (l1 = d[0], u1 = d[1]);
  #|                    var f = q(l1, u1, o3, h3, r1, c1, t, n);
  #|                    i = i.concat(f), t.bezierReflectionPoint = [
  #|                        r1 + (r1 - o3),
  #|                        c1 + (c1 - h3)
  #|                    ];
  #|                }
  #|                break;
  #|            }
  #|        case "Q":
  #|        case "q":
  #|            {
  #|                var _$s5 = "q" === e.key;
  #|                if (e.data.length >= 4) {
  #|                    var a6 = +e.data[0], o4 = +e.data[1], h4 = +e.data[2], r2 = +e.data[3];
  #|                    _$s5 && (a6 += t.x, h4 += t.x, o4 += t.y, r2 += t.y);
  #|                    var c2 = 1 * (1 + 0.2 * n.roughness), l2 = 1.5 * (1 + 0.22 * n.roughness);
  #|                    i.push({
  #|                        op: "move",
  #|                        data: [
  #|                            t.x + z(c2, n),
  #|                            t.y + z(c2, n)
  #|                        ]
  #|                    });
  #|                    var u2 = [
  #|                        h4 + z(c2, n),
  #|                        r2 + z(c2, n)
  #|                    ];
  #|                    i.push({
  #|                        op: "qcurveTo",
  #|                        data: [
  #|                            a6 + z(c2, n),
  #|                            o4 + z(c2, n),
  #|                            u2[0],
  #|                            u2[1]
  #|                        ]
  #|                    }), i.push({
  #|                        op: "move",
  #|                        data: [
  #|                            t.x + z(l2, n),
  #|                            t.y + z(l2, n)
  #|                        ]
  #|                    }), u2 = [
  #|                        h4 + z(l2, n),
  #|                        r2 + z(l2, n)
  #|                    ], i.push({
  #|                        op: "qcurveTo",
  #|                        data: [
  #|                            a6 + z(l2, n),
  #|                            o4 + z(l2, n),
  #|                            u2[0],
  #|                            u2[1]
  #|                        ]
  #|                    }), t.setPosition(u2[0], u2[1]), t.quadReflectionPoint = [
  #|                        h4 + (h4 - a6),
  #|                        r2 + (r2 - o4)
  #|                    ];
  #|                }
  #|                break;
  #|            }
  #|        case "T":
  #|        case "t":
  #|            {
  #|                var a7 = "t" === e.key;
  #|                if (e.data.length >= 2) {
  #|                    var o5 = +e.data[0], h5 = +e.data[1];
  #|                    a7 && (o5 += t.x, h5 += t.y);
  #|                    var r3 = o5, c3 = h5;
  #|                    var l3 = s ? s.key : "";
  #|                    var u3 = null;
  #|                    "q" !== l3 && "Q" !== l3 && "t" !== l3 && "T" !== l3 || (u3 = t.quadReflectionPoint), u3 && (r3 = u3[0], c3 = u3[1]);
  #|                    var p1 = 1 * (1 + 0.2 * n.roughness), d1 = 1.5 * (1 + 0.22 * n.roughness);
  #|                    i.push({
  #|                        op: "move",
  #|                        data: [
  #|                            t.x + z(p1, n),
  #|                            t.y + z(p1, n)
  #|                        ]
  #|                    });
  #|                    var f1 = [
  #|                        o5 + z(p1, n),
  #|                        h5 + z(p1, n)
  #|                    ];
  #|                    i.push({
  #|                        op: "qcurveTo",
  #|                        data: [
  #|                            r3 + z(p1, n),
  #|                            c3 + z(p1, n),
  #|                            f1[0],
  #|                            f1[1]
  #|                        ]
  #|                    }), i.push({
  #|                        op: "move",
  #|                        data: [
  #|                            t.x + z(d1, n),
  #|                            t.y + z(d1, n)
  #|                        ]
  #|                    }), f1 = [
  #|                        o5 + z(d1, n),
  #|                        h5 + z(d1, n)
  #|                    ], i.push({
  #|                        op: "qcurveTo",
  #|                        data: [
  #|                            r3 + z(d1, n),
  #|                            c3 + z(d1, n),
  #|                            f1[0],
  #|                            f1[1]
  #|                        ]
  #|                    }), t.setPosition(f1[0], f1[1]), t.quadReflectionPoint = [
  #|                        o5 + (o5 - r3),
  #|                        h5 + (h5 - c3)
  #|                    ];
  #|                }
  #|                break;
  #|            }
  #|        case "A":
  #|        case "a":
  #|            {
  #|                var _$s6 = "a" === e.key;
  #|                if (e.data.length >= 7) {
  #|                    var a8 = +e.data[0], o6 = +e.data[1], r4 = +e.data[2], c4 = +e.data[3], l4 = +e.data[4];
  #|                    var u4 = +e.data[5], p2 = +e.data[6];
  #|                    if (_$s6 && (u4 += t.x, p2 += t.y), u4 === t.x && p2 === t.y) break;
  #|                    if (0 === a8 || 0 === o6) i = i.concat(A(t.x, t.y, u4, p2, n)), t.setPosition(u4, p2);
  #|                    else for(var _$e = 0; _$e < 1; _$e++){
  #|                        var _$e1 = new h([
  #|                            t.x,
  #|                            t.y
  #|                        ], [
  #|                            u4,
  #|                            p2
  #|                        ], [
  #|                            a8,
  #|                            o6
  #|                        ], r4, !!c4, !!l4);
  #|                        var _$s7 = _$e1.getNextSegment();
  #|                        for(; _$s7;){
  #|                            var a9 = q(_$s7.cp1[0], _$s7.cp1[1], _$s7.cp2[0], _$s7.cp2[1], _$s7.to[0], _$s7.to[1], t, n);
  #|                            i = i.concat(a9), _$s7 = _$e1.getNextSegment();
  #|                        }
  #|                    }
  #|                }
  #|                break;
  #|            }
  #|    }
  #|    return i;
  #|}
  #|var N = "undefined" != typeof self, L = "none";
  #|var B = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function B(t, e) {
  #|        _class_call_check(this, B);
  #|        this.defaultOptions = {
  #|            maxRandomnessOffset: 2,
  #|            roughness: 1,
  #|            bowing: 1,
  #|            stroke: "#000",
  #|            strokeWidth: 1,
  #|            curveTightness: 0,
  #|            curveFitting: 0.95,
  #|            curveStepCount: 9,
  #|            fillStyle: "hachure",
  #|            fillWeight: -1,
  #|            hachureAngle: -41,
  #|            hachureGap: -1,
  #|            dashOffset: -1,
  #|            dashGap: -1,
  #|            zigzagOffset: -1,
  #|            seed: 0,
  #|            roughnessGain: 1
  #|        }, this.config = t || {}, this.surface = e, this.config.options && (this.defaultOptions = this._options(this.config.options));
  #|    }
  #|    _create_class(B, [
  #|        {
  #|            key: "_options",
  #|            value: function _options(t) {
  #|                return t ? Object.assign({}, this.defaultOptions, t) : this.defaultOptions;
  #|            }
  #|        },
  #|        {
  #|            key: "_drawable",
  #|            value: function _drawable(t, e, s) {
  #|                return {
  #|                    shape: t,
  #|                    sets: e || [],
  #|                    options: s || this.defaultOptions
  #|                };
  #|            }
  #|        },
  #|        {
  #|            key: "line",
  #|            value: function line(t, e, s, n, i) {
  #|                var a = this._options(i);
  #|                return this._drawable("line", [
  #|                    x(t, e, s, n, a)
  #|                ], a);
  #|            }
  #|        },
  #|        {
  #|            key: "rectangle",
  #|            value: function rectangle(t, e, s, n, i) {
  #|                var a = this._options(i), o = [], h = k(t, e, s, n, a);
  #|                if (a.fill) {
  #|                    var _$i = [
  #|                        [
  #|                            t,
  #|                            e
  #|                        ],
  #|                        [
  #|                            t + s,
  #|                            e
  #|                        ],
  #|                        [
  #|                            t + s,
  #|                            e + n
  #|                        ],
  #|                        [
  #|                            t,
  #|                            e + n
  #|                        ]
  #|                    ];
  #|                    "solid" === a.fillStyle ? o.push(S(_$i, a)) : o.push(O(_$i, a));
  #|                }
  #|                return a.stroke !== L && o.push(h), this._drawable("rectangle", o, a);
  #|            }
  #|        },
  #|        {
  #|            key: "ellipse",
  #|            value: function ellipse(t, e, s, n, i) {
  #|                var a = this._options(i), o = [], h = P(s, n, a), r = w(t, e, a, h);
  #|                if (a.fill) if ("solid" === a.fillStyle) {
  #|                    var _$s = w(t, e, a, h).opset;
  #|                    _$s.type = "fillPath", o.push(_$s);
  #|                } else o.push(O(r.estimatedPoints, a));
  #|                return a.stroke !== L && o.push(r.opset), this._drawable("ellipse", o, a);
  #|            }
  #|        },
  #|        {
  #|            key: "circle",
  #|            value: function circle(t, e, s, n) {
  #|                var i = this.ellipse(t, e, s, s, n);
  #|                return i.shape = "circle", i;
  #|            }
  #|        },
  #|        {
  #|            key: "linearPath",
  #|            value: function linearPath(t, e) {
  #|                var s = this._options(e);
  #|                return this._drawable("linearPath", [
  #|                    m(t, !1, s)
  #|                ], s);
  #|            }
  #|        },
  #|        {
  #|            key: "arc",
  #|            value: function arc(t, e, s, n, i, a) {
  #|                var o = arguments.length > 6 && arguments[6] !== void 0 ? arguments[6] : !1, h = arguments.length > 7 ? arguments[7] : void 0;
  #|                var r = this._options(h), c = [], l = v(t, e, s, n, i, a, o, !0, r);
  #|                if (o && r.fill) if ("solid" === r.fillStyle) {
  #|                    var o1 = v(t, e, s, n, i, a, !0, !1, r);
  #|                    o1.type = "fillPath", c.push(o1);
  #|                } else c.push(function(t, e, s, n, i, a, o) {
  #|                    var h = t, r = e;
  #|                    var c = Math.abs(s / 2), l = Math.abs(n / 2);
  #|                    c += z(0.01 * c, o), l += z(0.01 * l, o);
  #|                    var u = i, p = a;
  #|                    for(; u < 0;)u += 2 * Math.PI, p += 2 * Math.PI;
  #|                    p - u > 2 * Math.PI && (u = 0, p = 2 * Math.PI);
  #|                    var d = (p - u) / o.curveStepCount, f = [];
  #|                    for(var _$t = u; _$t <= p; _$t += d)f.push([
  #|                        h + c * Math.cos(_$t),
  #|                        r + l * Math.sin(_$t)
  #|                    ]);
  #|                    return f.push([
  #|                        h + c * Math.cos(p),
  #|                        r + l * Math.sin(p)
  #|                    ]), f.push([
  #|                        h,
  #|                        r
  #|                    ]), O(f, o);
  #|                }(t, e, s, n, i, a, r));
  #|                return r.stroke !== L && c.push(l), this._drawable("arc", c, r);
  #|            }
  #|        },
  #|        {
  #|            key: "curve",
  #|            value: function curve(t, e) {
  #|                var s = this._options(e);
  #|                return this._drawable("curve", [
  #|                    b(t, s)
  #|                ], s);
  #|            }
  #|        },
  #|        {
  #|            key: "polygon",
  #|            value: function polygon(t, e) {
  #|                var s = this._options(e), n = [], i = m(t, !0, s);
  #|                return s.fill && ("solid" === s.fillStyle ? n.push(S(t, s)) : n.push(O(t, s))), s.stroke !== L && n.push(i), this._drawable("polygon", n, s);
  #|            }
  #|        },
  #|        {
  #|            key: "path",
  #|            value: function path(t, e) {
  #|                var s = this._options(e), n = [];
  #|                if (!t) return this._drawable("path", n, s);
  #|                var i = function(t, e) {
  #|                    t = (t || "").replace(/\n/g, " ").replace(/(-\s)/g, "-").replace("/(\s\s)/g", " ");
  #|                    var s = new o(t);
  #|                    if (e.simplification) {
  #|                        var _$t = new r(s.linearPoints, s.closed).fit(e.simplification);
  #|                        s = new o(_$t);
  #|                    }
  #|                    var n = [];
  #|                    var i = s.segments || [];
  #|                    for(var _$t1 = 0; _$t1 < i.length; _$t1++){
  #|                        var a = $(s, i[_$t1], _$t1 > 0 ? i[_$t1 - 1] : null, e);
  #|                        a && a.length && (n = n.concat(a));
  #|                    }
  #|                    return {
  #|                        type: "path",
  #|                        ops: n
  #|                    };
  #|                }(t, s);
  #|                if (s.fill) if ("solid" === s.fillStyle) {
  #|                    var _$e = {
  #|                        type: "path2Dfill",
  #|                        path: t,
  #|                        ops: []
  #|                    };
  #|                    n.push(_$e);
  #|                } else {
  #|                    var _$e1 = this.computePathSize(t), i1 = O([
  #|                        [
  #|                            0,
  #|                            0
  #|                        ],
  #|                        [
  #|                            _$e1[0],
  #|                            0
  #|                        ],
  #|                        [
  #|                            _$e1[0],
  #|                            _$e1[1]
  #|                        ],
  #|                        [
  #|                            0,
  #|                            _$e1[1]
  #|                        ]
  #|                    ], s);
  #|                    i1.type = "path2Dpattern", i1.size = _$e1, i1.path = t, n.push(i1);
  #|                }
  #|                return s.stroke !== L && n.push(i), this._drawable("path", n, s);
  #|            }
  #|        },
  #|        {
  #|            key: "computePathSize",
  #|            value: function computePathSize(e) {
  #|                var s = [
  #|                    0,
  #|                    0
  #|                ];
  #|                if (N && self.document) try {
  #|                    var n = self.document.createElementNS(t, "svg");
  #|                    n.setAttribute("width", "0"), n.setAttribute("height", "0");
  #|                    var i = self.document.createElementNS(t, "path");
  #|                    i.setAttribute("d", e), n.appendChild(i), self.document.body.appendChild(n);
  #|                    var a = i.getBBox();
  #|                    a && (s[0] = a.width || 0, s[1] = a.height || 0), self.document.body.removeChild(n);
  #|                } catch (t) {}
  #|                var n1 = this.getCanvasSize();
  #|                return s[0] * s[1] || (s = n1), s;
  #|            }
  #|        },
  #|        {
  #|            key: "getCanvasSize",
  #|            value: function getCanvasSize() {
  #|                var t = function t(t) {
  #|                    return t && "object" == (typeof t === "undefined" ? "undefined" : _type_of(t)) && t.baseVal && t.baseVal.value ? t.baseVal.value : t || 100;
  #|                };
  #|                return this.surface ? [
  #|                    t(this.surface.width),
  #|                    t(this.surface.height)
  #|                ] : [
  #|                    100,
  #|                    100
  #|                ];
  #|            }
  #|        },
  #|        {
  #|            key: "opsToPath",
  #|            value: function opsToPath(t) {
  #|                var e = "";
  #|                var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                try {
  #|                    for(var _iterator = t.ops[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                        var s = _step.value;
  #|                        var _$t = s.data;
  #|                        switch(s.op){
  #|                            case "move":
  #|                                e += "M".concat(_$t[0], " ").concat(_$t[1], " ");
  #|                                break;
  #|                            case "bcurveTo":
  #|                                e += "C".concat(_$t[0], " ").concat(_$t[1], ", ").concat(_$t[2], " ").concat(_$t[3], ", ").concat(_$t[4], " ").concat(_$t[5], " ");
  #|                                break;
  #|                            case "qcurveTo":
  #|                                e += "Q".concat(_$t[0], " ").concat(_$t[1], ", ").concat(_$t[2], " ").concat(_$t[3], " ");
  #|                                break;
  #|                            case "lineTo":
  #|                                e += "L".concat(_$t[0], " ").concat(_$t[1], " ");
  #|                        }
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError = true;
  #|                    _iteratorError = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                            _iterator.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError) {
  #|                            throw _iteratorError;
  #|                        }
  #|                    }
  #|                }
  #|                return e.trim();
  #|            }
  #|        },
  #|        {
  #|            key: "toPaths",
  #|            value: function toPaths(t) {
  #|                var e = t.sets || [], s = t.options || this.defaultOptions, n = [];
  #|                var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                try {
  #|                    for(var _iterator = e[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                        var _$t = _step.value;
  #|                        var e1 = null;
  #|                        switch(_$t.type){
  #|                            case "path":
  #|                                e1 = {
  #|                                    d: this.opsToPath(_$t),
  #|                                    stroke: s.stroke,
  #|                                    strokeWidth: s.strokeWidth,
  #|                                    fill: L
  #|                                };
  #|                                break;
  #|                            case "fillPath":
  #|                                e1 = {
  #|                                    d: this.opsToPath(_$t),
  #|                                    stroke: L,
  #|                                    strokeWidth: 0,
  #|                                    fill: s.fill || L
  #|                                };
  #|                                break;
  #|                            case "fillSketch":
  #|                                e1 = this.fillSketch(_$t, s);
  #|                                break;
  #|                            case "path2Dfill":
  #|                                e1 = {
  #|                                    d: _$t.path || "",
  #|                                    stroke: L,
  #|                                    strokeWidth: 0,
  #|                                    fill: s.fill || L
  #|                                };
  #|                                break;
  #|                            case "path2Dpattern":
  #|                                {
  #|                                    var n1 = _$t.size, i = {
  #|                                        x: 0,
  #|                                        y: 0,
  #|                                        width: 1,
  #|                                        height: 1,
  #|                                        viewBox: "0 0 ".concat(Math.round(n1[0]), " ").concat(Math.round(n1[1])),
  #|                                        patternUnits: "objectBoundingBox",
  #|                                        path: this.fillSketch(_$t, s)
  #|                                    };
  #|                                    e1 = {
  #|                                        d: _$t.path,
  #|                                        stroke: L,
  #|                                        strokeWidth: 0,
  #|                                        pattern: i
  #|                                    };
  #|                                    break;
  #|                                }
  #|                        }
  #|                        e1 && n.push(e1);
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError = true;
  #|                    _iteratorError = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                            _iterator.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError) {
  #|                            throw _iteratorError;
  #|                        }
  #|                    }
  #|                }
  #|                return n;
  #|            }
  #|        },
  #|        {
  #|            key: "fillSketch",
  #|            value: function fillSketch(t, e) {
  #|                var s = e.fillWeight;
  #|                return s < 0 && (s = e.strokeWidth / 2), {
  #|                    d: this.opsToPath(t),
  #|                    stroke: e.fill || L,
  #|                    strokeWidth: s,
  #|                    fill: L
  #|                };
  #|            }
  #|        }
  #|    ], [
  #|        {
  #|            key: "newSeed",
  #|            value: function newSeed() {
  #|                return Math.floor(Math.random() * Math.pow(2, 31));
  #|            }
  #|        }
  #|    ]);
  #|    return B;
  #|}();
  #|var G = "undefined" != typeof document;
  #|var V = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function V(t, e) {
  #|        _class_call_check(this, V);
  #|        this.canvas = t, this.ctx = this.canvas.getContext("2d"), this.gen = new B(e, this.canvas);
  #|    }
  #|    _create_class(V, [
  #|        {
  #|            key: "draw",
  #|            value: function draw(t) {
  #|                var e = t.sets || [], s = t.options || this.getDefaultOptions(), n = this.ctx;
  #|                var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                try {
  #|                    for(var _iterator = e[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                        var _$t = _step.value;
  #|                        switch(_$t.type){
  #|                            case "path":
  #|                                n.save(), n.strokeStyle = "none" === s.stroke ? "transparent" : s.stroke, n.lineWidth = s.strokeWidth, this._drawToContext(n, _$t), n.restore();
  #|                                break;
  #|                            case "fillPath":
  #|                                n.save(), n.fillStyle = s.fill || "", this._drawToContext(n, _$t), n.restore();
  #|                                break;
  #|                            case "fillSketch":
  #|                                this.fillSketch(n, _$t, s);
  #|                                break;
  #|                            case "path2Dfill":
  #|                                {
  #|                                    this.ctx.save(), this.ctx.fillStyle = s.fill || "";
  #|                                    var e1 = new Path2D(_$t.path);
  #|                                    this.ctx.fill(e1), this.ctx.restore();
  #|                                    break;
  #|                                }
  #|                            case "path2Dpattern":
  #|                                {
  #|                                    var e2 = this.canvas.ownerDocument || G && document;
  #|                                    if (e2) {
  #|                                        var n1 = _$t.size, i = e2.createElement("canvas"), a = i.getContext("2d"), o = this.computeBBox(_$t.path);
  #|                                        o && (o.width || o.height) ? (i.width = this.canvas.width, i.height = this.canvas.height, a.translate(o.x || 0, o.y || 0)) : (i.width = n1[0], i.height = n1[1]), this.fillSketch(a, _$t, s), this.ctx.save(), this.ctx.fillStyle = this.ctx.createPattern(i, "repeat");
  #|                                        var h = new Path2D(_$t.path);
  #|                                        this.ctx.fill(h), this.ctx.restore();
  #|                                    } else console.error("Pattern fill fail: No defs");
  #|                                    break;
  #|                                }
  #|                        }
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError = true;
  #|                    _iteratorError = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                            _iterator.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError) {
  #|                            throw _iteratorError;
  #|                        }
  #|                    }
  #|                }
  #|            }
  #|        },
  #|        {
  #|            key: "computeBBox",
  #|            value: function computeBBox(e) {
  #|                if (G) try {
  #|                    var s = document.createElementNS(t, "svg");
  #|                    s.setAttribute("width", "0"), s.setAttribute("height", "0");
  #|                    var n = self.document.createElementNS(t, "path");
  #|                    n.setAttribute("d", e), s.appendChild(n), document.body.appendChild(s);
  #|                    var i = n.getBBox();
  #|                    return document.body.removeChild(s), i;
  #|                } catch (t) {}
  #|                return null;
  #|            }
  #|        },
  #|        {
  #|            key: "fillSketch",
  #|            value: function fillSketch(t, e, s) {
  #|                var n = s.fillWeight;
  #|                n < 0 && (n = s.strokeWidth / 2), t.save(), t.strokeStyle = s.fill || "", t.lineWidth = n, this._drawToContext(t, e), t.restore();
  #|            }
  #|        },
  #|        {
  #|            key: "_drawToContext",
  #|            value: function _drawToContext(t, e) {
  #|                t.beginPath();
  #|                var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                try {
  #|                    for(var _iterator = e.ops[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                        var s = _step.value;
  #|                        var _$e = s.data;
  #|                        switch(s.op){
  #|                            case "move":
  #|                                t.moveTo(_$e[0], _$e[1]);
  #|                                break;
  #|                            case "bcurveTo":
  #|                                t.bezierCurveTo(_$e[0], _$e[1], _$e[2], _$e[3], _$e[4], _$e[5]);
  #|                                break;
  #|                            case "qcurveTo":
  #|                                t.quadraticCurveTo(_$e[0], _$e[1], _$e[2], _$e[3]);
  #|                                break;
  #|                            case "lineTo":
  #|                                t.lineTo(_$e[0], _$e[1]);
  #|                        }
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError = true;
  #|                    _iteratorError = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                            _iterator.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError) {
  #|                            throw _iteratorError;
  #|                        }
  #|                    }
  #|                }
  #|                "fillPath" === e.type ? t.fill() : t.stroke();
  #|            }
  #|        },
  #|        {
  #|            key: "generator",
  #|            "get": function _get() {
  #|                return this.gen;
  #|            }
  #|        },
  #|        {
  #|            key: "getDefaultOptions",
  #|            value: function getDefaultOptions() {
  #|                return this.gen.defaultOptions;
  #|            }
  #|        },
  #|        {
  #|            key: "line",
  #|            value: function line(t, e, s, n, i) {
  #|                var a = this.gen.line(t, e, s, n, i);
  #|                return this.draw(a), a;
  #|            }
  #|        },
  #|        {
  #|            key: "rectangle",
  #|            value: function rectangle(t, e, s, n, i) {
  #|                var a = this.gen.rectangle(t, e, s, n, i);
  #|                return this.draw(a), a;
  #|            }
  #|        },
  #|        {
  #|            key: "ellipse",
  #|            value: function ellipse(t, e, s, n, i) {
  #|                var a = this.gen.ellipse(t, e, s, n, i);
  #|                return this.draw(a), a;
  #|            }
  #|        },
  #|        {
  #|            key: "circle",
  #|            value: function circle(t, e, s, n) {
  #|                var i = this.gen.circle(t, e, s, n);
  #|                return this.draw(i), i;
  #|            }
  #|        },
  #|        {
  #|            key: "linearPath",
  #|            value: function linearPath(t, e) {
  #|                var s = this.gen.linearPath(t, e);
  #|                return this.draw(s), s;
  #|            }
  #|        },
  #|        {
  #|            key: "polygon",
  #|            value: function polygon(t, e) {
  #|                var s = this.gen.polygon(t, e);
  #|                return this.draw(s), s;
  #|            }
  #|        },
  #|        {
  #|            key: "arc",
  #|            value: function arc(t, e, s, n, i, a) {
  #|                var o = arguments.length > 6 && arguments[6] !== void 0 ? arguments[6] : !1, h = arguments.length > 7 ? arguments[7] : void 0;
  #|                var r = this.gen.arc(t, e, s, n, i, a, o, h);
  #|                return this.draw(r), r;
  #|            }
  #|        },
  #|        {
  #|            key: "curve",
  #|            value: function curve(t, e) {
  #|                var s = this.gen.curve(t, e);
  #|                return this.draw(s), s;
  #|            }
  #|        },
  #|        {
  #|            key: "path",
  #|            value: function path(t, e) {
  #|                var s = this.gen.path(t, e);
  #|                return this.draw(s), s;
  #|            }
  #|        }
  #|    ]);
  #|    return V;
  #|}();
  #|var j = "undefined" != typeof document;
  #|var Q = /*#__PURE__*/ function() {
  #|    "use strict";
  #|    function Q(t, e) {
  #|        _class_call_check(this, Q);
  #|        this.svg = t, this.gen = new B(e, this.svg);
  #|    }
  #|    _create_class(Q, [
  #|        {
  #|            key: "defs",
  #|            "get": function _get() {
  #|                var e = this.svg.ownerDocument || j && document;
  #|                if (e && !this._defs) {
  #|                    var s = e.createElementNS(t, "defs");
  #|                    this.svg.firstChild ? this.svg.insertBefore(s, this.svg.firstChild) : this.svg.appendChild(s), this._defs = s;
  #|                }
  #|                return this._defs || null;
  #|            }
  #|        },
  #|        {
  #|            key: "draw",
  #|            value: function draw(e) {
  #|                var s = e.sets || [], n = e.options || this.getDefaultOptions(), i = this.svg.ownerDocument || window.document, a = i.createElementNS(t, "g");
  #|                var _iteratorNormalCompletion = true, _didIteratorError = false, _iteratorError = undefined;
  #|                try {
  #|                    for(var _iterator = s[Symbol.iterator](), _step; !(_iteratorNormalCompletion = (_step = _iterator.next()).done); _iteratorNormalCompletion = true){
  #|                        var _$e = _step.value;
  #|                        var s1 = null;
  #|                        switch(_$e.type){
  #|                            case "path":
  #|                                s1 = i.createElementNS(t, "path"), s1.setAttribute("d", this.opsToPath(_$e)), s1.style.stroke = n.stroke, s1.style.strokeWidth = n.strokeWidth + "", s1.style.fill = "none";
  #|                                break;
  #|                            case "fillPath":
  #|                                s1 = i.createElementNS(t, "path"), s1.setAttribute("d", this.opsToPath(_$e)), s1.style.stroke = "none", s1.style.strokeWidth = "0", s1.style.fill = n.fill || "";
  #|                                break;
  #|                            case "fillSketch":
  #|                                s1 = this.fillSketch(i, _$e, n);
  #|                                break;
  #|                            case "path2Dfill":
  #|                                s1 = i.createElementNS(t, "path"), s1.setAttribute("d", _$e.path || ""), s1.style.stroke = "none", s1.style.strokeWidth = "0", s1.style.fill = n.fill || "";
  #|                                break;
  #|                            case "path2Dpattern":
  #|                                if (this.defs) {
  #|                                    var a1 = _$e.size, o = i.createElementNS(t, "pattern"), h = "rough-".concat(Math.floor(Math.random() * (Number.MAX_SAFE_INTEGER || 999999)));
  #|                                    o.setAttribute("id", h), o.setAttribute("x", "0"), o.setAttribute("y", "0"), o.setAttribute("width", "1"), o.setAttribute("height", "1"), o.setAttribute("height", "1"), o.setAttribute("viewBox", "0 0 ".concat(Math.round(a1[0]), " ").concat(Math.round(a1[1]))), o.setAttribute("patternUnits", "objectBoundingBox");
  #|                                    var r = this.fillSketch(i, _$e, n);
  #|                                    o.appendChild(r), this.defs.appendChild(o), s1 = i.createElementNS(t, "path"), s1.setAttribute("d", _$e.path || ""), s1.style.stroke = "none", s1.style.strokeWidth = "0", s1.style.fill = "url(#".concat(h, ")");
  #|                                } else console.error("Pattern fill fail: No defs");
  #|                        }
  #|                        s1 && a.appendChild(s1);
  #|                    }
  #|                } catch (err) {
  #|                    _didIteratorError = true;
  #|                    _iteratorError = err;
  #|                } finally{
  #|                    try {
  #|                        if (!_iteratorNormalCompletion && _iterator.return != null) {
  #|                            _iterator.return();
  #|                        }
  #|                    } finally{
  #|                        if (_didIteratorError) {
  #|                            throw _iteratorError;
  #|                        }
  #|                    }
  #|                }
  #|                return a;
  #|            }
  #|        },
  #|        {
  #|            key: "fillSketch",
  #|            value: function fillSketch(e, s, n) {
  #|                var i = n.fillWeight;
  #|                i < 0 && (i = n.strokeWidth / 2);
  #|                var a = e.createElementNS(t, "path");
  #|                return a.setAttribute("d", this.opsToPath(s)), a.style.stroke = n.fill || "", a.style.strokeWidth = i + "", a.style.fill = "none", a;
  #|            }
  #|        },
  #|        {
  #|            key: "generator",
  #|            "get": function _get() {
  #|                return this.gen;
  #|            }
  #|        },
  #|        {
  #|            key: "getDefaultOptions",
  #|            value: function getDefaultOptions() {
  #|                return this.gen.defaultOptions;
  #|            }
  #|        },
  #|        {
  #|            key: "opsToPath",
  #|            value: function opsToPath(t) {
  #|                return this.gen.opsToPath(t);
  #|            }
  #|        },
  #|        {
  #|            key: "line",
  #|            value: function line(t, e, s, n, i) {
  #|                var a = this.gen.line(t, e, s, n, i);
  #|                return this.draw(a);
  #|            }
  #|        },
  #|        {
  #|            key: "rectangle",
  #|            value: function rectangle(t, e, s, n, i) {
  #|                var a = this.gen.rectangle(t, e, s, n, i);
  #|                return this.draw(a);
  #|            }
  #|        },
  #|        {
  #|            key: "ellipse",
  #|            value: function ellipse(t, e, s, n, i) {
  #|                var a = this.gen.ellipse(t, e, s, n, i);
  #|                return this.draw(a);
  #|            }
  #|        },
  #|        {
  #|            key: "circle",
  #|            value: function circle(t, e, s, n) {
  #|                var i = this.gen.circle(t, e, s, n);
  #|                return this.draw(i);
  #|            }
  #|        },
  #|        {
  #|            key: "linearPath",
  #|            value: function linearPath(t, e) {
  #|                var s = this.gen.linearPath(t, e);
  #|                return this.draw(s);
  #|            }
  #|        },
  #|        {
  #|            key: "polygon",
  #|            value: function polygon(t, e) {
  #|                var s = this.gen.polygon(t, e);
  #|                return this.draw(s);
  #|            }
  #|        },
  #|        {
  #|            key: "arc",
  #|            value: function arc(t, e, s, n, i, a) {
  #|                var o = arguments.length > 6 && arguments[6] !== void 0 ? arguments[6] : !1, h = arguments.length > 7 ? arguments[7] : void 0;
  #|                var r = this.gen.arc(t, e, s, n, i, a, o, h);
  #|                return this.draw(r);
  #|            }
  #|        },
  #|        {
  #|            key: "curve",
  #|            value: function curve(t, e) {
  #|                var s = this.gen.curve(t, e);
  #|                return this.draw(s);
  #|            }
  #|        },
  #|        {
  #|            key: "path",
  #|            value: function path(t, e) {
  #|                var s = this.gen.path(t, e);
  #|                return this.draw(s);
  #|            }
  #|        }
  #|    ]);
  #|    return Q;
  #|}();
  #|var rough = {
  #|    canvas: function canvas(t, e) {
  #|        return new V(t, e);
  #|    },
  #|    svg: function svg(t, e) {
  #|        return new Q(t, e);
  #|    },
  #|    generator: function generator(t, e) {
  #|        return new B(t, e);
  #|    },
  #|    newSeed: function newSeed() {
  #|        return B.newSeed();
  #|    }
  #|};
  #|

///|
let sketch_setup_source : String =
  #|var root = {
  #|    ownerDocument: {
  #|        createElementNS: function createElementNS(ns, tagName) {
  #|            var children = [];
  #|            var attrs = {};
  #|            var style = {};
  #|            return {
  #|                style: style,
  #|                tagName: tagName,
  #|                attrs: attrs,
  #|                setAttribute: function setAttribute(key, value) {
  #|                    return attrs[key] = value;
  #|                },
  #|                appendChild: function appendChild(node) {
  #|                    return children.push(node);
  #|                },
  #|                children: children
  #|            };
  #|        }
  #|    }
  #|};
  #|var rc = rough.svg(root, {
  #|    seed: 1
  #|});
  #|var node;
  #|if (typeof globalThis !== "undefined") {
  #|    globalThis.rc = rc;
  #|}
  #|

///|
let sketch_streaks_pattern_template : String =
  #|<pattern id="streaks-%s-%s" x="0" y="0" width="100" height="100" patternUnits="userSpaceOnUse">
  #|    <path fill="%s" fill-rule="evenodd" clip-rule="evenodd" d="M58.1193 0H58.1703L55.4939 2.67644L58.1193 0ZM45.7725 0H45.811L41.2851 4.61498L42.7191 3.29325L37.0824 8.92997L35.0554 10.9569L32.0719 13.9404L29.6229 16.5017L27.1738 19.0631L25.8089 20.2034L23.2195 22.6244L18.181 27.6068L23.8178 21.97L27.0615 18.9508L33.8666 11.9773L33.1562 12.5194L37.0262 8.87383L40.784 5.11602L38.0299 7.64561L45.7725 0ZM23.1079 0H23.108L21.5814 1.66688L20.3126 2.79534L23.1079 0ZM7.53869 0H7.54254L7.50005 0.035944L7.53869 0ZM2.49995 0H2.52362L0.900245 1.59971L2.49995 0ZM0 3.64398V3.60744L0.278386 3.36559L0 3.64398ZM0 18.6564V18.5398L0.67985 17.8416L3.4459 15.0755L1.15701 17.1333L2.78713 15.6022L6.01437 12.507L8.5168 9.87253L5.15803 13.2313L11.0357 7.25453L10.4926 7.89678L13.6868 4.7686L8.54982 9.90555L7.05177 11.5687L4.68087 13.9396L0.729379 17.8911L3.01827 15.8333L0 18.6564ZM0 69.2431V69.178L1.64651 67.4763L1.46347 67.7796L5.84063 63.4025L4.42167 64.9016L0 69.4007V69.3408L0.247596 68.9955L0 69.2431ZM2.51594 100H2.49238L5.19989 97.2925L7.70071 95.0162L12.8713 89.6772L12.3094 90.0707L15.288 87.3167L18.1542 84.4504L16.0269 86.3532L22.8752 79.6172L18.5364 84.0683L19.6435 83.0734L15.3441 87.3728L13.798 88.9189L11.5224 91.1945L9.66768 93.1615L7.81297 95.1285L6.74529 95.9716L4.75024 97.7983L2.51594 100ZM7.54255 100H7.5387L9.81396 97.884L8.46606 99.2189L7.54255 100ZM45.8189 100H45.7807L46.9912 98.8047L45.8189 100ZM58.1784 100H58.1272L62.2952 95.7511L66.1408 91.9055L63.0037 94.8115L65.2507 92.6635L69.7117 88.3346L73.2165 84.6977L68.5469 89.3673L76.7379 81.0773L75.9634 81.9509L80.3913 77.5889L73.2496 84.7307L71.1346 87.0107L67.8384 90.3069L62.3447 95.8006L65.4818 92.8947L61.2625 96.9159L58.1784 100ZM75.4277 100H75.229L82.1834 92.9039L81.3403 93.5787L86.0063 89.1371L90.5601 84.5833L87.2464 87.6725L98.0937 76.9375L91.1673 83.9761L92.8932 82.3625L86.0625 89.1933L83.6062 91.6496L79.9907 95.265L77.011 98.357L75.4277 100ZM100 18.5398V18.6563L99.9556 18.6979L95.8065 22.847L100 18.5398ZM100 3.60743V3.64398L99.6791 3.9649L99.2094 4.29428L100 3.60743ZM75.4201 0L74.0312 1.4412L72.401 2.84687L69.281 5.79854L63.1812 11.8422L70.0119 5.01151L73.919 1.32893L75.2214 0H75.4201ZM100 69.1858V69.2509L98.059 71.1919L100 69.1858ZM100 69.3486V69.4085L99.8414 69.5698L100 69.3486ZM41.9398 28.8254L53.6223 16.993L52.5215 18.2437L54.7428 16.0575L54.6875 16.0759L54.8008 16.0004L58.842 12.0231L54.9925 15.8726L55.1085 15.7953L54.898 16.0058L54.84 16.0251L48.6523 22.2128L45.6419 25.473L40.9389 30.1759L33.1007 38.0142L37.5866 33.878L31.558 39.6068L23.3278 47.837L33.0257 37.9393L38.5125 32.4525L34.0266 36.5887L37.2369 33.5283L43.6074 27.3576L48.6023 22.1628L41.9398 28.8254ZM41.0977 17.0531L39.718 18.2925L40.312 17.8388L41.0977 17.0531ZM36.875 20.3106L48.1601 7.88137L42.3438 13.7478L36.875 20.3106ZM35.7125 25.8109L34.3328 27.0503L34.9268 26.5966L35.7125 25.8109ZM17.7022 39.7534L19.0819 38.514L18.8092 38.7867L36.7575 21.8045L23.1569 35.3051L13.5771 43.7372L18.1448 39.4154L17.7022 39.7534ZM3.48102 28.9281L1.53562 30.8735L1.22228 31.0465L0.0765686 32.3326L1.60579 30.9437L2.57849 29.971L3.48102 28.9281ZM0.953463 26.2027L19.5702 7.58594L9.31575 18.6078L0.953463 26.2027ZM23.7175 12.11L17.9339 18.0875L21.4622 14.5592L20.8074 15.4725L28.1915 7.95918L30.4791 5.54232L23.4224 12.599L23.7175 12.11ZM43.4641 43.1538L40.7872 46.1552L42.4907 44.4517L42.3285 45.0465L45.8166 41.3421L46.8441 40.0983L43.4371 43.5053L43.4641 43.1538ZM1.32715 48.3271L8.0918 41.5625L4.3657 45.5674L1.32715 48.3271ZM11.1479 31.2556L11.5689 30.975L11.3584 31.1855L11.1479 31.2556ZM11.9898 27.4667L12.2003 27.2562L11.7793 27.5369L11.9898 27.4667ZM11.3585 34.5531L11.148 34.7636L10.9375 34.8338L11.3585 34.5531ZM72.929 28.5457L82.2965 19.0792L81.4043 20.0705L86.4597 15.0811L78.2983 23.2425L75.8697 25.8362L72.1029 29.603L65.8249 35.881L69.3934 32.5437L64.5858 37.1531L57.994 43.745L65.7754 35.8314L70.17 31.4369L66.6015 34.7742L69.1623 32.3125L74.2507 27.3562L78.2653 23.2095L72.929 28.5457ZM82.6674 1.83549L84.3245 0.31872L83.3724 1.27088L82.6674 1.83549ZM64.5872 16.1312L62.9301 17.648L63.6351 17.0834L64.5872 16.1312ZM70.868 9.85044L80.0048 1.1214L74.6221 6.47142L70.868 9.85044ZM90.2409 41.9448L70.7578 61.4279L79.5093 53.4795L90.2409 41.9448ZM91.8088 42.5434L95.3963 38.8357L95.2132 39.139L99.5904 34.7618L98.1714 36.261L93.5912 40.9214L93.9973 40.3549L91.8088 42.5434ZM94.331 12.8233L89.9853 17.1691L89.2853 17.5555L86.7259 20.4284L90.142 17.3258L92.3149 15.1529L94.331 12.8233ZM44.7972 62.3259L76.9824 30.1406L59.2542 49.1955L44.7972 62.3259ZM77.1482 40.321L70.1709 47.5323L70 47.6463L70.0895 47.6164L68.1916 49.5779L70.185 47.5846L70.2105 47.5761L70.421 47.3656L70.37 47.3996L73.6557 44.1139L72.6416 45.5283L84.0768 33.893L87.6194 30.1502L76.6913 41.0783L77.1482 40.321ZM50.5355 34.3137L72.6617 12.1875L60.4955 25.3084L50.5355 34.3137ZM70.2104 44.0681L70.6314 43.7875L70.4209 43.998L70.2104 44.0681ZM71.263 40.0687L70.842 40.3494L71.0525 40.2792L71.263 40.0687ZM55.1084 12.4355L55.3189 12.225L54.8979 12.5056L55.1084 12.4355ZM48.8718 15.5785L60.2075 4.70496L49.4056 15.4006L48.8718 15.5785ZM23.7636 57.4491L29.9099 51.5854L26.1656 55.6123L27.2361 54.8244L23.435 58.6255L22.0681 59.9924L20.0562 62.0042L18.5082 63.8349L16.9601 65.6656L15.8328 66.2277L13.9315 67.7051L10.4821 71.0132L14.2832 67.2121L16.6775 65.383L21.1113 60.5253L20.477 60.7357L23.2937 58.4842L25.8277 55.9502L23.7636 57.4491ZM48.3825 74.1824L44.8832 77.8523L46.9145 75.8211L45.4748 77.4881L43.4493 79.2862L42.4082 80.1568L43.9215 79.0414L42.2487 80.7143L39.3752 83.8151L41.8844 81.3059L43.8473 79.6842L42.334 80.7995L44.7237 78.4098L46.1576 76.976L46.9713 75.8779L50.078 72.7713L48.1093 74.6262L48.3825 74.1824ZM29.2877 62.9906L29.0772 63.2011L28.8667 63.2713L29.2877 62.9906ZM29.7088 59.4823L29.9193 59.2719L29.4983 59.5525L29.7088 59.4823ZM29.0772 66.5687L28.8667 66.7792L28.6562 66.8494L29.0772 66.5687ZM22.9729 68.748L23.1834 68.5375L22.7624 68.8181L22.9729 68.748ZM3.8147e-05 91.7593L13.2499 79.1355L6.5001 86.2595L3.8147e-05 91.7593ZM16.0685 87.9974L17.1375 87.0687L16.5382 87.668L16.0685 87.9974ZM21.7869 79.3344L20.7179 80.263L21.1876 79.9337L21.7869 79.3344ZM12.3607 95.0755L13.4298 94.1469L12.8304 94.7462L12.3607 95.0755ZM42.7176 59.3801L43.2789 58.8187L43.0684 59.1696L42.7877 59.4502L42.2966 59.801L42.5772 59.3801H42.7176ZM26.3124 49.3152L24.3599 51.2676L23.996 51.3918L22.8956 52.732L24.4798 51.3875L25.456 50.4113L26.3124 49.3152ZM39.0689 63.3097L38.5777 63.6606L39.56 62.6782L39.0689 63.3097ZM20.3574 55.8032L19.3751 56.7856L19.8662 56.4347L20.3574 55.8032ZM39.9297 64.195L41.5504 62.3779L41.534 62.5907L43.5967 60.528L42.9746 61.2811L40.8628 63.5238L40.961 63.1637L39.9297 64.195ZM22.3921 55.457L21.3998 56.5696L22.0313 55.9381L21.9711 56.1587L23.2642 54.7854L23.6451 54.3243L22.3821 55.5873L22.3921 55.457ZM40.6473 92.4498L45.0485 88.0485L43.0066 90.4079L40.806 92.6085L37.3463 95.7507L39.9384 92.8412L40.6473 92.4498ZM18.5042 48.7973L11.5457 55.7558L10.4249 56.3746L6.32684 60.9746L11.7967 56.0067L15.2759 52.5275L18.5042 48.7973ZM32.7113 78.139L31.1131 79.7372L30.8432 79.8668L29.9145 80.9358L31.1833 79.8074L31.9823 79.0083L32.7113 78.139ZM21.7577 93.9525L31.2855 84.0344L30.8324 84.8777L42.4999 73.2102L38.7408 77.2295L26.5552 89.6753L27.5914 88.1187L21.7577 93.9525ZM98.5132 90.0591L89.9224 97.9224L93.5769 94.9953L98.5132 90.0591ZM97.8456 80.2105L99.5027 78.6937L98.5506 79.6459L97.8456 80.2105ZM88.5656 56.4599L78.9205 65.7009L82.1262 63.3036L78.1413 67.2885L73.7522 70.8692L74.7195 70.5082L67.717 78.117L63.992 81.0336L58.0146 87.011L63.4289 81.7988L66.3887 79.4454L68.1212 78.5213L70.5757 75.6625L73.0302 72.8038L76.194 69.64L78.3434 67.4906L84.3208 61.5132L82.6575 62.7723L88.5656 56.4599ZM85.1893 67.0375L83.7304 68.356L84.3561 67.8707L85.1893 67.0375ZM90.7969 58.2022L99.2725 50.5418L94.4317 55.3826L90.7969 58.2022ZM79.377 76.2172L77.9182 77.5357L78.5438 77.0504L79.377 76.2172ZM59.4922 91.7253L56.4011 94.1231L60.0049 90.8659L63.6087 87.6087L59.4922 91.7253ZM63.8833 75.4153L46 92.3896L49.6884 89.1193L53.3767 85.8491L63.8833 75.4153ZM71.6063 55.0765L69.6609 57.0219L69.3475 57.1949L68.2018 58.481L69.731 57.0921L70.7037 56.1194L71.6063 55.0765ZM55.1405 71.6857L61.4131 65.4131L57.958 69.1267L55.1405 71.6857ZM65.8396 69.4497L61.7138 73.7138L64.2308 71.1968L63.7637 71.8484L69.0313 66.4886L70.6632 64.7645L65.6292 69.7985L65.8396 69.4497ZM53.0034 65.4955L58.2258 59.8914L58.0558 60.4431L64.5517 53.9472L62.5136 56.2398L55.7841 63.2238L56.2513 62.2475L53.0034 65.4955ZM97.0997 71.2032L79.6514 88.6515L86.7697 80.814L97.0997 71.2032ZM35.1848 56.2513L31.93 59.9006L34.0012 57.8294L33.804 58.5527L38.0451 54.0485L39.2945 52.5361L35.1519 56.6787L35.1848 56.2513ZM66.8712 26.2471L78.1907 14.3099L77.7244 15.394L91.6784 1.4399L87.233 6.29715L72.7096 21.2323L73.8482 19.2701L66.8712 26.2471ZM28.0473 68.2068L20.4355 76.375L25.1695 71.641L24.4884 73.0639L34.297 62.8844L37.2675 59.5429L27.7995 69.0109L28.0473 68.2068ZM8.94067 39.5658L14.1631 33.9617L13.993 34.5134L20.4889 28.0175L18.4509 30.3101L11.7213 37.2941L12.1886 36.3178L8.94067 39.5658ZM99.7403 26L88 37.7404L93.2735 32.9508L99.7403 26ZM1.93388 8.08743L4.77765 5.04974L4.67856 5.34275L8.20743 1.81388L7.09578 3.05481L3.4355 6.84437L3.69832 6.32299L1.93388 8.08743ZM54.4485 44.211L48.5985 50.061L47.6563 50.5813L44.211 54.4485L48.8095 50.272L51.7345 47.347L54.4485 44.211Z" />
  #|</pattern>
