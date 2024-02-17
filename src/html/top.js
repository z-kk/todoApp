function statusCell(cell, node) {
    const sel = document.createElement("select");
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

    if (taskStatus[node.status] == "Hide" || taskStatus[node.status] == "Waiting") {
        const lbl = document.createElement("label");
        lbl.style.marginRight = "8px";
        lbl.innerText = "for:";
        const dt = document.createElement("input");
        dt.type = "date";
        dt.value = node.for;
        const d = document.createElement("div");
        d.classList.add("row");
        d.style.width = "100%";
        d.style.marginLeft = "0";
        d.appendChild(lbl);
        d.appendChild(dt);
        cell.appendChild(d);
    }
}

function dueCell(cell, due) {
    if (due) {
        const dt = document.createElement("input");
        dt.type = "date";
        dt.value = due;
        cell.appendChild(dt);
    }
}

function updateButton(cell) {
    let btn = document.createElement("button");
    btn.type = "button";
    btn.innerText = "update";
    cell.appendChild(btn);

    btn = document.createElement("button");
    btn.type = "button";
    btn.innerText = "delete";
    cell.appendChild(btn);
}

function resetData() {
    fetch(appName + "/data", {
        method: "GET",
    }).then(response => {
        if (!response.ok) {
            throw new Error("response error");
        }
        return response.json();
    }).then(data => {
        for (proj of data) {
            let tr = select("#maintable").insertRow();
            let ipt = document.createElement("input");
            ipt.value = proj.proj
            tr.insertCell().appendChild(ipt);
            for (title of proj.data.filter((val) => { return taskStatus[val.status] != "Done" })) {
                tr = select("#maintable").insertRow();
                tr.insertCell();
                ipt = document.createElement("input");
                ipt.value = title.title;
                tr.insertCell().appendChild(ipt);
                tr.insertCell();
                statusCell(tr.insertCell(), title);
                dueCell(tr.insertCell(), title.due);
                updateButton(tr.insertCell());
                for (child of title.children.filter((val) => { return taskStatus[val.status] != "Done" })) {
                    tr = select("#maintable").insertRow();
                    tr.insertCell();
                    tr.insertCell();
                    ipt = document.createElement("input");
                    ipt.value = child.title;
                    tr.insertCell().appendChild(ipt);
                    statusCell(tr.insertCell(), child);
                    dueCell(tr.insertCell(), child.due);
                    updateButton(tr.insertCell());
                }
            }
        }
    }).catch(err => {
        alert(err);
    });
}

self.window.addEventListener('load', function() {
    resetData();
});
