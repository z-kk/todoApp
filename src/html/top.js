function isWaitOrHide(val) {
    const sts = taskStatus[val];
    return (sts == "Waiting" || sts == "Hide");
}

function filterStatus(node) {
    return node.filter((val) => { return taskStatus[val.status] != "Done" });
}

function update() {
    const node = {uuid: this.value};
    const tr = this.parentNode.parentNode;
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
            const dt = tr.querySelector(".for");
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
            show(this.parentNode.querySelector(".row"));
        } else {
            hide(this.parentNode.querySelector(".row"));
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
    const d = document.createElement("div");
    d.classList.add("row");
    d.style.width = "100%";
    d.style.marginLeft = "0";
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
    cell = tr.insertCell();
    cell.appendChild(btn);

    btn = document.createElement("button");
    btn.type = "button";
    btn.innerText = "delete";
    btn.classList.add("delete");
    btn.value = node.uuid;
    cell.appendChild(btn);
}

function resetData(data) {
    const tbody = select("#maintable");
    let idx = 0;
    for (proj of data) {
        if (filterStatus(proj.data).length == 0) {
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
        for (title of filterStatus(proj.data)) {
            while (tbody.children.length < idx + 1) {
                tbody.insertRow();
            }
            tr = tbody.children[idx++];
            while (tr.firstChild) {
                tr.removeChild(tr.firstChild);
            }
            updateRow(tr, title, true);
            for (child of filterStatus(title.children)) {
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

self.window.addEventListener('load', function() {
    fetch(appName + "/data", {
        method: "GET",
    }).then(response => {
        if (!response.ok) {
            throw new Error("response error");
        }
        return response.json();
    }).then(data => {
        resetData(data);
    }).catch(err => {
        alert(err);
    });
});
