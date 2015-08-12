;(function(){
'use strict';

$(document).ready(function(){
	var myId;
	var voices = {};
	$('select').material_select();
	window.speechSynthesis.onvoiceschanged = function(){
		window.speechSynthesis.getVoices().map(function(voice){
			if (!voices[voice.lang]) {
				$('#voice')
					//.find('option')
					//.remove()
					//.end()
					.append('<option value="'+ voice.lang +'">'+ voice.name +'</option>');
				voices[voice.lang] = true;
			}
		});
		$('select').material_select();
	};
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
				msg.voice = window.speechSynthesis.getVoices().filter(function(e){
					return e.lang === $('#voice').find(':selected').prop('value');
				})[0];
				window.speechSynthesis.speak(msg);
			},
			'speach.heard': function(key, content, raw) {
				if (raw.from === myId) {
					return;
				}
				var msg = new SpeechSynthesisUtterance(content.spoken);
				msg.voice = window.speechSynthesis.getVoices().filter(function(e){
					return e.lang === content.voice;
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
					voice: $('#voice').find(':selected').prop('value')
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
