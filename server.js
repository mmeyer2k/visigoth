const express = require('express')
const nunjucks = require('nunjucks')
const app = express()
const port = 4242
const redis = require('redis').createClient()

app.use(express.urlencoded())

nunjucks.configure(__dirname, {
    autoescape: true,
    express: app
})

app.set('views', __dirname)
app.set('view engine', 'html')

app.get('/', (request, response) => {
    var timeAgo = require('node-time-ago');
    redis
        .multi()
        .smembers('rules:allow')
        .smembers('rules:block')
        .smembers('rules:hosts')
        .get('keep:rules')
        .get('mode:last')
        .exec((err, results) => {
            return response.render('index', {
                allow: results[0],
                block: results[1],
                hosts: results[2],
                stamp: timeAgo(new Date(results[3] || (new Date()).toISOString())),
                mode: results[4],
            })
        })
})

app.get('/dynamic.yaml', (request, response) => {
    response.sendFile("/shared/rules/00_dynamic.yaml")
})

app.get('/favicon.ico', (request, response) => {
    response.sendFile("/shared/favicon.ico")
})

app.get('/jquery.js', (request, response) => {
    response.sendFile("/shared/node_modules/jquery/dist/jquery.min.js")
})

app.post('/mode/:mode',  (request, response) => {
    redis
        .multi()
        .set(['mode:last', request.params.mode])
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

app.post('/list/hosts/add', (request, response) => {
    redis.sadd(['rules:hosts',  request.body.ip + ' ' + request.body.domain])
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