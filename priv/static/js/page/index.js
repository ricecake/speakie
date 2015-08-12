;(function(){
'use strict';

$(document).ready(function(){
        var connection = new KnotConn({
		url: '/ws/',
		eventHandlers: {
			'#': function(key, content, raw) {
				console.log([key, content, raw]);
			},
			'speach.heard': function(key, content, raw) {
				var msg = new SpeechSynthesisUtterance(content.spoken)
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
	recognition.interimResults = false;
	recognition.onresult = function(event) {
		console.log(event);
		for (var i = event.resultIndex; i < event.results.length; ++i) {
			if (event.results[i].isFinal) {
				var message = {
					spoken: event.results[i][0].transcript,
					voice: "Google UK English Male"
				};
				connection.send('speach.heard', message);
			}
		}
	};
	recognition.start();

});

}());
