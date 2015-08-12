;(function(){
'use strict';

$(document).ready(function(){
        var connection = new KnotConn({
		url: '/ws/',
		eventHandlers: {
			'#': function(key, content, raw) {
				console.log([key, content, raw]);
			}
		},
		onOpen: function() {
			connection.send('session.join', { channel: $('#knot-channel-name').val() });
			$('#knot-chat').knotChat({
				connection: connection
			});
			$('#knot-edit').knotGroupEdit({
				connection: connection
			});
			$('#knot-video').knotVideoChat({});
			$('#knot-board').knotWhiteBoard({});
		}
	});
});

}());
var recognition = new webkitSpeechRecognition();
recognition.continuous = true;
recognition.interimResults = false;
recognition.onresult = function(event) {
	console.log(event);
	for (var i = event.resultIndex; i < event.results.length; ++i) {
		if (event.results[i].isFinal) {
			var msg = new SpeechSynthesisUtterance(event.results[i][0].transcript)
			msg.voice = window.speechSynthesis.getVoices()[1];
			window.speechSynthesis.speak(msg);
		}
	}
};
recognition.start();
