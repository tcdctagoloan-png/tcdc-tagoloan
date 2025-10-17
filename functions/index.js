const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const MAX_CAPACITY_PER_BED = 4;
const MAX_SLOTS_PER_TIME = 16;

/**
 * Returns Firestore timestamps for a given slot on a specific date.
 * @param {Date} date
 * @param {string} slot Format "HH:MM-HH:MM"
 * @returns {{start: admin.firestore.Timestamp, end: admin.firestore.Timestamp}}
 */
function getSlotTimestamps(date, slot) {
  const [startStr, endStr] = slot.split("-");
  const [startH, startM] = startStr.split(":").map(Number);
  const [endH, endM] = endStr.split(":").map(Number);

  const start = new Date(date);
  start.setHours(startH, startM, 0, 0);

  const end = new Date(date);
  end.setHours(endH, endM, 0, 0);

  return {
    start: admin.firestore.Timestamp.fromDate(start),
    end: admin.firestore.Timestamp.fromDate(end),
  };
}

/**
 * Sends an FCM notification to a user.
 * @param {string} uid
 * @param {string} title
 * @param {string} body
 */
async function sendNotification(uid, title, body) {
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) return;
  const token = userDoc.data().fcmToken;
  if (!token) return;

  await admin.messaging().send({
    token,
    notification: { title, body },
  });
}

/**
 * Auto-manages appointments every hour.
 */
exports.autoManageAppointments = functions.pubsub
  .schedule("every 60 minutes")
  .onRun(async () => {
    const apptsSnap = await db
      .collection("appointments")
      .where("status", "in", ["approved"])
      .get();

    const updates = [];
    const notifications = [];

    for (const doc of apptsSnap.docs) {
      const data = doc.data();
      const date = data.date ? data.date.toDate() : null;
      const slot = data.slot;
      if (!date || !slot) continue;

      const { start, end } = getSlotTimestamps(date, slot);

      // Auto-complete finished appointments
      if (end.toDate() < new Date()) {
        updates.push(
          db.collection("appointments").doc(doc.id).update({ status: "completed" })
        );
        notifications.push(
          sendNotification(
            data.patientId,
            "Dialysis Complete",
            "Your dialysis session is complete. You can now book your next follow-up session."
          )
        );
        continue;
      }

      // Missed appointments
      if (start.toDate() < new Date()) {
        updates.push(
          db.collection("appointments").doc(doc.id).update({ status: "didnt_show" })
        );

        const nextDate = await findNextAvailableSlot();
        if (nextDate) {
          updates.push(
            db.collection("appointments").add({
              patientId: data.patientId,
              status: "rescheduled",
              date: nextDate.date,
              slot: nextDate.slot,
              bedId: nextDate.bedId,
              createdAt: admin.firestore.Timestamp.now(),
            })
          );

          notifications.push(
            sendNotification(
              data.patientId,
              "Appointment Auto-Rescheduled",
              `Your missed appointment has been rescheduled to ${nextDate.date
                .toDate()
                .toDateString()} at ${nextDate.slot}`
            )
          );
        } else {
          updates.push(
            db.collection("didnt_show_list").doc(doc.id).set({
              patientId: data.patientId,
              originalAppointment: doc.id,
              createdAt: admin.firestore.Timestamp.now(),
            })
          );
        }
      }
    }

    await Promise.all([...updates, ...notifications]);
    console.log("Auto-management of appointments completed.");
    return null;
  });

/**
 * Finds the next available slot considering bed capacity and slot limits.
 * @returns {Promise<{date: admin.firestore.Timestamp, slot: string, bedId: string} | null>}
 */
async function findNextAvailableSlot() {
  const today = new Date();
  for (let i = 1; i <= 30; i++) {
    const candidateDate = new Date(today);
    candidateDate.setDate(today.getDate() + i);

    const slotsSnap = await db
      .collection("sessions")
      .where("sessionDate", "==", admin.firestore.Timestamp.fromDate(candidateDate))
      .get();

    for (const slotDoc of slotsSnap.docs) {
      const slotData = slotDoc.data();
      if (!slotData.isActive) continue;
      const slot = slotData.slot;

      const apptsSnap = await db
        .collection("appointments")
        .where("date", ">=", admin.firestore.Timestamp.fromDate(candidateDate))
        .where(
          "date",
          "<",
          admin.firestore.Timestamp.fromDate(
            new Date(candidateDate.getTime() + 24 * 60 * 60 * 1000)
          )
        )
        .where("slot", "==", slot)
        .where("status", "in", ["pending", "approved", "rescheduled"])
        .get();

      if (apptsSnap.size >= MAX_SLOTS_PER_TIME) continue;

      const bedsSnap = await db.collection("beds").where("isWorking", "==", true).orderBy("name").get();

      for (const bedDoc of bedsSnap.docs) {
        const bedId = bedDoc.id;
        const assignedCount = apptsSnap.docs.filter((a) => a.data().bedId === bedId).length;
        if (assignedCount < MAX_CAPACITY_PER_BED) {
          return {
            date: admin.firestore.Timestamp.fromDate(candidateDate),
            slot,
            bedId,
          };
        }
      }
    }
  }
  return null;
}
