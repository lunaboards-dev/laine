function deleteT(id) {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			location.reload(true)
		}
	};
	xmlhttp.open("POST", board+"/post", true);
	xmlhttp.setRequestHeader("Content-type", "application/json");
	xmlhttp.send(JSON.stringify({content:"@mark", board: board, id: id}));
}
function lock(id) {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			location.reload(true)
		}
	};
	xmlhttp.open("POST", board+"/post", true);
	xmlhttp.setRequestHeader("Content-type", "application/json");
	xmlhttp.send(JSON.stringify({content:"@lock", board: board, id: id}));
}
function pin(id) {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			location.reload(true)
		}
	};
	xmlhttp.open("POST", board+"/post", true);
	xmlhttp.setRequestHeader("Content-type", "application/json");
	xmlhttp.send(JSON.stringify({content:"@pin", board: board, id: id}));
}
function unpin(id) {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			location.reload(true)
		}
	};
	xmlhttp.open("POST", board+"/post", true);
	xmlhttp.setRequestHeader("Content-type", "application/json");
	xmlhttp.send(JSON.stringify({content:"@unpin", board: board, id: id}));
}
function unlock(id) {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			location.reload(true)
		}
	};
	xmlhttp.open("POST", "/post", true);
	xmlhttp.setRequestHeader("Content-type", "application/json");
	xmlhttp.send(JSON.stringify({content:"@unlock", board: board, id: id}));
}
function ipban(ip) {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			location.reload(true)
		}
	};
	xmlhttp.open("POST", window.location.href.replace(id, "post"), true);
	xmlhttp.setRequestHeader("Content-type", "application/json");
	xmlhttp.send(JSON.stringify({content:"@banip", ip: ip, board: board, id: id}));
}
function deleteP(rid) {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.onreadystatechange = function() {
		if (this.readyState == 4 && this.status == 200) {
			location.reload(true)
		}
	};
	xmlhttp.open("POST", window.location.href.replace(id, "post"), true);
	xmlhttp.setRequestHeader("Content-type", "application/json");
	xmlhttp.send(JSON.stringify({content:"@del", rid: rid, board: board, id: id}));
}