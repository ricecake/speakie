;(function(){
'use strict';

$(document).ready(function(){
	var myId;
        var connection = new KnotConn({
		url: '/ws/',
		eventHandlers: {
			'#': function(key, content, raw) {
				console.log([key, content, raw]);
			},
			'session.data': function(key, content) {
				myId = content.id;
			},
			"channel.connected": function() {
				var msg = new SpeechSynthesisUtterance("A new user has connected");
				msg.voice = window.speechSynthesis.getVoices()[0];
				window.speechSynthesis.speak(msg);
			},
			'speach.heard': function(key, content, raw) {
				if (raw.from === myId) {
					return;
				}
				var msg = new SpeechSynthesisUtterance(content.spoken);
				msg.voice = window.speechSynthesis.getVoices().filter(function(e){
					return e.name === content.voice;
				})[0];
				window.speechSynthesis.speak(msg);
			}
		},
		onOpen: function() {
			connection.send('session.join', { channel: 'mainpage' });
		}
	});
	var recognition = new webkitSpeechRecognition();
	recognition.continuous = true;
	recognition.interimResults = true;
	recognition.onresult = function(event) {
		console.log(event);
		for (var i = event.resultIndex; i < event.results.length; ++i) {
			if (event.results[i].isFinal) {
				$('#output').text(event.results[i][0].transcript);
				var message = {
					spoken: event.results[i][0].transcript,
					voice: "Google UK English Male"
				};
				connection.send('speach.heard', message);
			} else {
				$('#output').text(event.results[i][0].transcript);
			}
		}
	};
	recognition.onend = function() {
		recognition.start();
	};
	recognition.start();
});

}());
