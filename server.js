const express = require('express')
const nunjucks = require('nunjucks')
const app = express()
const port = 4242
const redis = require('redis').createClient()
const morgan = require('morgan')
const moment = require('moment')

app.use(express.urlencoded())
app.use(morgan('dev'))

nunjucks.configure(__dirname, {
    autoescape: true,
    express: app
})

app.set('views', __dirname)
app.set('view engine', 'njk')

app.get('/', (request, response) => {
    redis
        .multi()
        .smembers('rules:allow')
        .smembers('rules:block')
        .smembers('rules:hosts')
        .get('notracking:hash')
        .get('keep:rules')
        .get('mode:last')
        .get('mode:next')
        .ttl('mode:time')
        .exec((err, results) => {
            return response.render('index', {
                allow: results[0].sort(),
                block: results[1].sort(),
                hosts: results[2].sort(),
                stamp: moment(new Date(results[4] || (new Date()).toISOString())).fromNow(),
                track: results[3],
                mode: results[5],
                next: results[6],
                time: Math.ceil(results[7] / 60),
            })
        })
})

app.get('/favicon.ico', (request, response) => {
    response.sendFile("/shared/favicon.ico")
})

app.get('/jquery.js', (request, response) => {
    response.sendFile("/shared/node_modules/jquery/dist/jquery.min.js")
})

app.get('/bulma.css', (request, response) => {
    response.sendFile("/shared/node_modules/bulma/css/bulma.min.css")
})

app.post('/mode/:mode', (request, response) => {
    var mode = request.params.mode

    if (mode === 'off-60') {
        redis.setex('mode:time', 60 * 60, '')
        redis.rename('mode:last', 'mode:next')
        mode = 'off'
    } else {
        redis.del('mode:next', 'mode:time')
    }

    redis
        .multi()
        .set(['mode:last', mode])
        .del('keep:rules')
        .exec((err, results) => {
            return response.redirect('/')
        })
})

app.post('/flush', (request, response) => {
    redis.del(['keep:rules', 'rules:allow', 'rules:block'], (err, result) => {
        return response.redirect('/')
    })
})

app.get('/rules/static', (request, response) => {
    response.sendFile("/shared/hosts/static.json")
})

app.post('/list/hosts/add', (request, response) => {
    redis.sadd(['rules:hosts', request.body.ip + ' ' + request.body.domain])
    redis.del(['keep:rules'])
    response.redirect('/')
})

app.post('/list/:list/add', (request, response) => {
    redis.sadd(['rules:' + request.params.list, request.body.domain])
    redis.del(['keep:rules'])
    response.redirect('/')
})

app.post('/list/:list/remove/:domain', (request, response) => {
    redis.srem(['rules:' + request.params.list, request.params.domain])
    redis.del(['keep:rules'])
    response.redirect('/')
})

app.listen(port, (err) => {
    if (err) {
        return console.log('something bad happened', err)
    }

    console.log(`server is listening on ${port}`)
})
