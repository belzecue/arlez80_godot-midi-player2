/*
	計算
*/
var table = [];

function down(from, rate) {
	var to = from - 12;
	var halfRate = rate / 2;

	for( var i=0; i<12; i++ ) {
		var note = to + i;
		if( 0 <= note ) {
			table[note] = Math.round( halfRate * Math.pow( 2, i / 12 ) );
		}
	}

	if( 0 < to ) {
		down( to, halfRate );
	}
}
function up(from, rate) {
	var to = from + 12;

	for( var i=1; i<=12; i++ ) {
		var note = i + from;
		if( note <= 127 ) {
			table[note] = Math.round( rate * Math.pow( 2, i / 12 ) );
		}
	}

	if( to < 127 ) {
		up( to, rate * 2 );
	}
}

table[69] = 44100;
down(69, 44100);
up(69, 44100);
JSON.stringify( table )
