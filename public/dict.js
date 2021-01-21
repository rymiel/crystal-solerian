const api = {
    base: "/api/jsemb/v2/",
    dict(offset) {
        return this.base + "dict?l=25&s=" + offset;
    },
    locate(hash) {
        return this.base + "locate/" + hash;
    }
}

const state = {
    perPage: 25,
    page: NaN,
    lastCalculatedMaxPage: NaN,
    lastCalculatedMax: NaN,
    lastOffset: NaN,
    isReady: false,
    isSetup: false,
    currentProcess: null,
};

var getJSON = function(url, callback) {
    if (state.currentProcess) {
        state.currentProcess.abort();
    }
    var xhr = new XMLHttpRequest();
    state.currentProcess = xhr;
    xhr.open('GET', url, true);
    xhr.responseType = 'json';
    xhr.onload = function() {
      var status = xhr.status;
      if (status === 200) {
        callback(null, xhr.response);
      } else {
        callback(status, xhr.response);
      }
    };
    xhr.send();
};

function htmlToElement(html) {
    var template = document.createElement('template');
    html = html.trim(); // Never return a text node of whitespace as the result
    template.innerHTML = html;
    return template.content.firstChild;
}

var refreshTable = function(page, savePage = true) {
    page = parseInt(page, 10);
    console.log("refreshTable(" + page + ", " + savePage + ")")
    let realUpdateFlag = page !== state.page;
    state.page = page;
    state.lastOffset = page * state.perPage;
    let startAt = state.page * state.perPage + 1;
    let finishAt = (state.page + 1) * state.perPage;
    finishAt = Math.min(finishAt, state.lastCalculatedMax);
    let maxPage = Math.floor(state.lastCalculatedMax / state.perPage) + 1;
    if (!isNaN(state.lastCalculatedMax))
    document.getElementById("pageswitcher").innerHTML = "Entries " + startAt + " - " + finishAt + " of " + state.lastCalculatedMax + " (Page " + (state.page + 1) + " of " + maxPage + ")";
    if (realUpdateFlag) {
        setLoading();
        getJSON(api.dict(state.lastOffset), applyJSON);
        if (savePage)
            if (page > 0)
                history.replaceState(undefined, undefined, "##" + (page + 1));
            else {
                history.replaceState(undefined, undefined, "#");
                history.replaceState(undefined, undefined, window.location.href.slice(0, -1));
            }
    }
};

var applyJSON = function(status, data) {
    if (data.status === "ok") {
        data = data.response;
        if (data.start !== state.lastOffset && !isNaN(state.lastOffset)) {
            return;
        }
        resetTable();
        state.lastCalculatedMax = data.max;
        let maxPage = Math.floor(state.lastCalculatedMax / state.perPage) + 1;
        state.lastCalculatedMaxPage = maxPage - 1;
        if (!state.isSetup) {
            state.isSetup = true;
            refreshTable(state.page);
        }
        finishLoading();
        let table = document.getElementById("jsdict");
        data = data.dict;
        data.forEach((i) => {
            table.appendChild(htmlToElement(
                `<tr id="${i.hash}">
                    <td><a href="#${i.hash}">${i.num}</a></td>
                    <td>${i.eng}</td>
                    ${i.link ? `
                    <td><a href="${i.link}?s=${i.sol}"><i>${i.sol}</i></a></td>
                    <td class="sol"><a href="${i.link}?s=${i.sol}">${i.script}</a></td>
                    ` : `
                    <td><i>${i.sol}</i></td>
                    <td class="sol">${i.script}</td>
                    `}
                    <td>${i.extra}</td>
                    ${i.is_bold ? `
                    <td><b>${i.ipa}</b></td>
                    ` : `
                    <td>${i.ipa}</td>
                    `}
                </tr>`
            ))
        });
        if (window.location.hash) {
            window.location.href = window.location.hash;
        }
    } else {
        alert("Something went wrong with the JS table, please report the following error: " + data.response);
    }
};

var resetTable = function() {
    let parent = document.getElementById("jsdict");
    [...parent.childNodes].forEach(el => {if (el.nodeName !== "#text" && !el.classList.contains("persistent")) el.remove() });
};

var initialSetup = function() {
    if (window.location.hash) {
        var hash = window.location.hash.substring(1);
        if (hash[0] === "#") {
            if (state.isReady) {
                refreshTable(hash.substring(1) - 1);
            }
        } else {
            getJSON(api.locate(hash), applyHash)
        }
    } else if (state.isReady) {
        refreshTable(0)
    }
}

var applyHash = function(status, num) {
    if (num.status === "ok") {
        let func = () => refreshTable(Math.floor(num.response / state.perPage), false);
        if (state.isReady)
            func();
        else
            window.onload = () => {state.isReady = true; func()};
    } else {
        alert("Something went wrong with the hash location, please report the following error: " + num.response);
    }
}

var setPage = function(offset) {
    if (state.isReady && state.page + offset >= 0 && state.page + offset <= state.lastCalculatedMaxPage) refreshTable(parseInt(state.page, 10) + offset);
}

var setLoading = function() {
    document.getElementById("jsdict").classList.add("dark");
}

var finishLoading = function() {
    document.getElementById("jsdict").classList.remove("dark");
}

initialSetup()
window.onload = () => {state.isReady = true; initialSetup()};
window.onhashchange = initialSetup;

