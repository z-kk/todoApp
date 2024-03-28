const holiday = [];

function isWaitOrHide(val) {
    const sts = taskStatus[val];
    return (sts == "Waiting" || sts == "Hide");
}

function filterStatus(node, containHide) {
    const res = node.filter((val) => { return taskStatus[val.status] != "Done" });
    if (containHide) {
        return res;
    } else {
        return res.filter((val) => { return taskStatus[val.status] != "Hide" });
    }
}

function update() {
    const node = {uuid: this.value};
    const tr = this.parentNode.parentNode.parentNode;
    let proj = tr.querySelector(".proj");
    let idx = tr.rowIndex;
    while (proj == null) {
        idx--;
        proj = tr.parentNode.children[idx].querySelector(".proj");
    }
    node.proj = proj.value;
    let title = tr.querySelector(".title");
    idx = tr.rowIndex;
    while (title == null) {
        idx--;
        title = tr.parentNode.children[idx].querySelector(".title");
    }
    if (idx == tr.rowIndex) {
        node.title = title.value;
    } else {
        node.parent = tr.parentNode.children[idx].querySelector(".update").value;
        const detail = tr.querySelector(".detail");
        if (detail) {
            node.title = detail.value;
        }
    }
    const status = tr.querySelector(".status");
    if (status) {
        node.status = status.value;
        if (isWaitOrHide(node.status)) {
            const dt = tr.querySelector("input.for");
            if (dt && dt.value) {
                node.for = dt.value;
            } else {
                alert("for value is required!");
                dt.focus();
                return;
            }
        }
    }
    const due = tr.querySelector(".due");
    if (due && due.value) {
        node.due = due.value;
    }

    fetch(appName + "/update", {
        method: "POST",
        body: JSON.stringify(node),
    }).then(response => {
        if (!response.ok) {
            throw new Error("response error");
        }
        return response.json();
    }).then(data => {
        if (!data.result) {
            throw new Error(data.err);
        }
        resetData(data.data);
        setMermaid(data.data);
    }).catch(err => {
        alert(err);
    });
}

function deleteData() {
    const node = {uuid: this.value};

    fetch(appName + "/delete", {
        method: "POST",
        body: JSON.stringify(node),
    }).then(response => {
        if (!response.ok) {
            throw new Error("response error");
        }
        return response.json();
    }).then(data => {
        if (!data.result) {
            throw new Error(data.err);
        }
        resetData(data.data);
        setMermaid(data.data);
    }).catch(err => {
        alert(err);
    });
}

function addButton(target) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.innerText = "add";
    btn.classList.add(target);
    btn.addEventListener('click', function() {
        const node = {
            "title": "",
            "status": 0,
            "uuid": Math.random().toString(16).substring(2),
        };
        const idx = this.parentNode.parentNode.rowIndex;
        if (target == "proj") {
            updateRow(select("#maintable").insertRow(idx - 1), node, true);
            const ipt = document.createElement("input");
            ipt.classList.add("proj");
            select("#maintable").children[idx - 1].children[0].appendChild(ipt);
        } else {
            updateRow(select("#maintable").insertRow(idx), node, target == "title");
        }
    });
    return btn;
}

function updateRow(tr, node, isTitle) {
    tr.insertCell();
    const ipt = document.createElement("input");
    ipt.value = node.title;
    if (isTitle) {
        ipt.classList.add("title");
        tr.insertCell().appendChild(ipt);
        tr.insertCell().appendChild(addButton("detail"));
    } else {
        ipt.classList.add("detail");
        tr.insertCell();
        tr.insertCell().appendChild(ipt);
    }

    let cell = tr.insertCell();
    const sel = document.createElement("select");
    sel.classList.add("status");
    sel.addEventListener('change', function() {
        if (isWaitOrHide(this.value)) {
            show(this.parentNode.querySelector("div.for"));
        } else {
            hide(this.parentNode.querySelector("div.for"));
        }
    });
    for (let i = 0; i < taskStatus.length; i++) {
        const opt = document.createElement("option");
        opt.value = i;
        opt.innerText = taskStatus[i];
        if (node.status == i) {
            opt.selected = true;
        }
        sel.appendChild(opt);
    }
    cell.appendChild(sel);

    const lbl = document.createElement("label");
    lbl.style.marginRight = "8px";
    lbl.innerText = "for:";
    let dt = document.createElement("input");
    dt.type = "date";
    dt.classList.add("for");
    let d = document.createElement("div");
    d.classList.add("nowrap");
    d.classList.add("for");
    d.appendChild(lbl);
    if (isWaitOrHide(node.status)) {
        dt.value = node.for;
    } else {
        hide(d);
    }
    d.appendChild(dt);
    cell.appendChild(d);

    dt = document.createElement("input");
    dt.type = "date";
    dt.classList.add("due");
    if (node.due) {
        dt.value = node.due;
    }
    tr.insertCell().appendChild(dt);

    let btn = document.createElement("button");
    btn.type = "button";
    btn.innerText = "update";
    btn.classList.add("update");
    btn.value = node.uuid;
    btn.addEventListener('click', update);
    d = document.createElement("div");
    d.classList.add("nowrap");
    d.appendChild(btn);

    btn = document.createElement("button");
    btn.type = "button";
    btn.innerText = "delete";
    btn.classList.add("delete");
    btn.style.marginLeft = "2px";
    btn.value = node.uuid;
    btn.addEventListener('click', deleteData);
    d.appendChild(btn);

    cell = tr.insertCell();
    cell.appendChild(d);
}

function resetData(data) {
    const tbody = select("#maintable");
    let idx = 0;
    for (proj of data) {
        if (filterStatus(proj.data, true).length == 0) {
            continue;
        }
        while (tbody.children.length < idx + 1) {
            tbody.insertRow();
        }
        let tr = tbody.children[idx++];
        while (tr.firstChild) {
            tr.removeChild(tr.firstChild);
        }
        const ipt = document.createElement("input");
        ipt.classList.add("proj");
        ipt.value = proj.proj
        tr.insertCell().appendChild(ipt);
        tr.insertCell().appendChild(addButton("title"));
        for (title of filterStatus(proj.data, true)) {
            while (tbody.children.length < idx + 1) {
                tbody.insertRow();
            }
            tr = tbody.children[idx++];
            while (tr.firstChild) {
                tr.removeChild(tr.firstChild);
            }
            updateRow(tr, title, true);
            for (child of filterStatus(title.children, true)) {
                while (tbody.children.length < idx + 1) {
                    tbody.insertRow();
                }
                tr = tbody.children[idx++];
                while (tr.firstChild) {
                    tr.removeChild(tr.firstChild);
                }
                updateRow(tr, child, false);
            }
        }
    }
    while (tbody.children[idx]) {
        tbody.removeChild(tbody.children[idx]);
    }
    tbody.insertRow().insertCell().appendChild(addButton("proj"));
}

function setMermaid(data) {
    const today = new Date();
    let d = select(".mermaid");
    if (d == null) {
        d = document.createElement("div");
        d.classList.add("mermaid");
        select("main").prepend(d);
    } else {
        delete d.dataset.processed;
    }
    let mmd = `gantt
        dateFormat YYYY-MM-DD
        axisFormat %m/%d
        excludes weekends ${holiday.join(" ")}
    \n`
    for (proj of data) {
        if (filterStatus(proj.data, false).length == 0) {
            continue;
        }
        if (proj.proj == "") {
            proj.proj = "other";
        }
        mmd += `    section ${proj.proj}\n`;
        for (title of filterStatus(proj.data, false)) {
            let gstatus = ""
            if (taskStatus[title.status] == "Doing") {
                gstatus = "active";
            }
            let from = getDateString(today);
            if (isWaitOrHide(title.status) && title.for > from) {
                from = title.for;
            }
            let due = new Date(today.getTime());
            if (title.due) {
                due = new Date(title.due);
                if (due < today) {
                    from = getDateString(due);
                    gstatus = "milestone";
                }
            } else if (title.for) {
                due = new Date(title.for);
                gstatus = "milestone";
            }
            due.setDate(due.getDate() + 1);
            if (gstatus) {
                gstatus += ",";
            }
            mmd += `        ${title.title}: ${gstatus}${title.uuid},${from},${getDateString(due)}\n`;
            for (child of filterStatus(title.children, false)) {
                gstatus = "";
                if (taskStatus[child.status] == "Doing") {
                    gstatus = "active";
                }
                from = getDateString(today);
                if (isWaitOrHide(child.status) && child.for > from) {
                    from = child.for;
                }
                due = new Date(today.getTime());
                if (child.due) {
                    due = new Date(child.due);
                    if (due < today) {
                        from = getDateString(due);
                        gstatus = "milestone";
                    }
                }
                due.setDate(due.getDate() + 1);
                if (gstatus) {
                    gstatus += ",";
                }
                mmd += `        ${child.title}: ${gstatus}${child.uuid},${from},${getDateString(due)}\n`;
            }
        }
    }
    d.innerHTML = mmd;

    const mermaidUrl = "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs";
    import(mermaidUrl).then(module => {
        if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
            let themeCSS = ".exclude-range {fill: var(--nc-bg-3)}";
            themeCSS += " .task {fill: var(--nc-ac-1)}";
            for (i = 0; i < 4; i++) {
                themeCSS += ` .active${i} {fill: var(--nc-lk-2)}`;
            }
            module.default.init({
                theme: "dark",
                themeCSS: themeCSS,
            });
        } else {
            module.default.init();
        }
    });
}

self.window.addEventListener('load', function() {
    fetch("https://holidays-jp.github.io/api/v1/date.json").then(response => {
        if (!response.ok) {
            throw new Error("response error");
        }
        return response.json();
    }).then(data => {
        for (key in data) {
            holiday.push(key);
        }
    }).catch(err => {
        alert(err);
    });

    fetch(appName + "/data", {
        method: "GET",
    }).then(response => {
        if (!response.ok) {
            throw new Error("response error");
        }
        return response.json();
    }).then(data => {
        resetData(data);
        setMermaid(data);
    }).catch(err => {
        alert(err);
    });
});
