flow.set('device_status_cache', flow.get('device_status_cache') || {});

const deviceName = msg.payload.avdevicename;
const newStatus = msg.payload.avnewstatus;

const cache = flow.get('device_status_cache');

if (cache[deviceName]) {
    if (cache[deviceName].status === newStatus) {
        return null;
    }
}

cache[deviceName] = {
    timestamp: Date.now(),
    status: newStatus
};
flow.set('device_status_cache', cache);

let port = 1905;
let ip = global.get("con_ip");

if (!ip || typeof ip !== "string" || !ip.match(/^(\d{1,3}\.){3}\d{1,3}$/)) {
    return null;
}

let url = `http://${ip}:${port}`;

return {
    payload: {
        room: msg.payload.room,
        avdevicename: deviceName,
        avnewstatus: newStatus,
        type: msg.payload.type
    },
    url: url,
    _original: {
        topic: msg.topic,
        payload: msg.payload
    }
};
