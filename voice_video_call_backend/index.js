const express = require('express');
const app = express();
const http = require('http').createServer(app);
const { Server } = require("socket.io"); // Import Socket.IO server
const cors = require('cors');
const dotenv = require('dotenv');
dotenv.config();
const {
    FIREBASE_PUSH_NOTIFICATION_TYPE,
    FIREBASE_PUSH_NOTIFICATION_PROJECT_ID,
    FIREBASE_PUSH_NOTIFICATION_PRIVATE_KEY_ID,
    FIREBASE_PUSH_NOTIFICATION_PRIVATE_KEY,
    FIREBASE_PUSH_NOTIFICATION_CLIENT_EMAIL,
    FIREBASE_PUSH_NOTIFICATION_CLIENT_ID,
    FIREBASE_PUSH_NOTIFICATION_AUTH_URI,
    FIREBASE_PUSH_NOTIFICATION_TOKEN_URI,
    FIREBASE_PUSH_NOTIFICATION_AUTH_PROVIDER_X509_CERT_URL,
    FIREBASE_PUSH_NOTIFICATION_CLIENT_X509_CERT_URL,
    FIREBASE_PUSH_NOTIFICATION_UNIVERSE_DOMAIN
} = process.env


var admin = require("firebase-admin");

var serviceAccount = require("./serviceAccountKeys.json");

admin.initializeApp({
  credential: admin.credential.cert({
    type: FIREBASE_PUSH_NOTIFICATION_TYPE,
    project_id: FIREBASE_PUSH_NOTIFICATION_PROJECT_ID,
    private_key_id: FIREBASE_PUSH_NOTIFICATION_PRIVATE_KEY_ID,
    private_key: FIREBASE_PUSH_NOTIFICATION_PRIVATE_KEY.replace(/\\n/g, '\n'),
    client_email: FIREBASE_PUSH_NOTIFICATION_CLIENT_EMAIL,
    client_id: FIREBASE_PUSH_NOTIFICATION_CLIENT_ID,
    auth_uri: FIREBASE_PUSH_NOTIFICATION_AUTH_URI,
    token_uri: FIREBASE_PUSH_NOTIFICATION_TOKEN_URI,
    auth_provider_x509_cert_url: FIREBASE_PUSH_NOTIFICATION_AUTH_PROVIDER_X509_CERT_URL,
    client_x509_cert_url: FIREBASE_PUSH_NOTIFICATION_CLIENT_X509_CERT_URL,
    universe_domain: FIREBASE_PUSH_NOTIFICATION_UNIVERSE_DOMAIN
  })
});

const db = admin.firestore();

let customerRef = db.collection("reconnectUsers");
let iceRef = db.collection("reconnectIceCandidates");

// customerRef.get().then((querySnapshot)=>{
//   querySnapshot.forEach(document => {
//     console.log(document.data());
//   })
// })


let port = process.env.PORT || 9000;

const io = new Server(http, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

io.use((socket, next) => {
  if (socket.handshake.query) {
    let callerId = socket.handshake.query.callerId;
    socket.user = callerId;
    next();
  }
});

io.on("connection", (socket) => {
  console.log(socket.user, "Connected");
  socket.join(socket.user);

  // Check callee data on connection
  customerRef.doc(socket.user).get()
    .then((docSnapshot) => {
      if (docSnapshot.exists) {
        const calleeData = docSnapshot.data();
        if (calleeData.calleeId === socket.user) {
          // calleeId matches socket.user, resend offer data if available
          const offerRef = db.collection("reconnectUsers").doc(socket.user);
          offerRef.get()
            .then((offerSnapshot) => {
              if (offerSnapshot.exists) {
                const offerData = offerSnapshot.data();
                socket.emit("newCall", offerData);
              } else {
                console.log("No offer data found for callee:", socket.user);
              }
            })
            .catch((error) => {
              console.error("Error getting offer data:", error);
            });
        }
      } else {
        console.log("No document found for calleeId:", socket.user);
      }
    })
    .catch((error) => {
      console.error("Error getting document:", error);
    });

  // iceRef.doc(socket.user).get()
  // .then((docSnapshot) => {
  //   if (docSnapshot.exists) {
  //     const calleeData = docSnapshot.data();
  //     if (calleeData.sender === socket.user) {
  //       // calleeId matches socket.user, resend offer data if available
  //       const iceRef = db.collection("reconnectIceCandidates").doc(socket.user);
  //       iceRef.get()
  //         .then((iceSnapshot) => {
  //           if (iceSnapshot.exists) {
  //             const iceData = iceSnapshot.data();
  //             socket.emit("IceCandidate", iceData);
  //           } else {
  //             console.log("No ice candidates found for callee:", socket.user);
  //           }
  //         })
  //         .catch((error) => {
  //           console.error("Error getting ice candidates:", error);
  //         });
  //     }
  //   } else {
  //     console.log("No ice document found for calleeId:", socket.user);
  //   }
  // })
  // .catch((error) => {
  //   console.error("Error getting document:", error);
  // });

  socket.on("makeCall", (data) => {
    let calleeId = data.calleeId;
    let sdpOffer = data.sdpOffer;
    console.log(sdpOffer);

    customerRef.doc(calleeId).set({
      calleeId: calleeId,
      sdpOffer: sdpOffer,
      callerId: socket.user,
      // Add any other relevant data here (callerId, timestamp, etc.)
    })
      .then(() => {
        console.log("Offer data updated for calleeId:", calleeId);
      })
      .catch((error) => {
        console.error("Error updating offer data:", error);
      });

    socket.to(calleeId).emit("newCall", {
      callerId: socket.user,
      sdpOffer: sdpOffer,
    });
  });

  socket.on("answerCall", (data) => {
    let callerId = data.callerId;
    let sdpAnswer = data.sdpAnswer;
    console.log(sdpAnswer);

    socket.to(callerId).emit("callAnswered", {
      callee: socket.user,
      sdpAnswer: sdpAnswer,
    });
  });

  socket.on("IceCandidate", (data) => {
    let calleeId = data.calleeId;
    let iceCandidate = data.iceCandidate;
    console.log('IceCandidates data', iceCandidate);

    // iceRef.doc(calleeId).set({
    //   calleeId: calleeId,
    //   iceCandidate: iceCandidate,
    //   sender: socket.user,
    //   // Add any other relevant data here (callerId, timestamp, etc.)
    // })
    //   .then(() => {
    //     console.log("ice candidates updated for calleeId:", calleeId);
    //   })
    //   .catch((error) => {
    //     console.error("Error updating ice candidates :", error);
    //   });

    socket.to(calleeId).emit("IceCandidate", {
      sender: socket.user,
      iceCandidate: iceCandidate,
    });
  });

  socket.on("endCall", (data) => {
    let calleeId = data.calleeId;
    let callerId = data.callerId;
    console.log('end call from', callerId);

    const docRef = db.collection("reconnectUsers").doc(calleeId);
    if(docRef){
      docRef.delete().then(() => {
        console.log("Document deleted successfully!");
      }).catch((error) => {
        console.error("Error deleting document:", error);
      });
    } else{
      console.log('there is no data');
    }
   
    if(callerId === socket.user){
      socket.to(calleeId).emit("endConnectivity", {
        sender: callerId,
      })
    } else{
      socket.to(callerId).emit("endConnectivity", {
        sender: calleeId,
      })
    }
    
  })
});

app.get('/', (req, res) => res.send('Hello World!'));

http.listen(port, () => console.log(`Listening on port ${port}`));
