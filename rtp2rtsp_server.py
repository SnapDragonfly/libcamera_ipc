from gi.repository import Gst, GstRtspServer
from gi.repository import GLib

def main():
    Gst.init(None)

    # Create the RTSP server
    server = GstRtspServer.RTSPServer()
    server.set_service("8554")  # Set RTSP server port

    # Create the media factory
    factory = GstRtspServer.RTSPMediaFactory()

    # Launch pipeline for receiving UDP packets on port 5602 and decoding
    pipeline_str = (
        "udpsrc port=5602 ! "
        "application/x-rtp,encoding-name=H264,payload=96 ! "
        "rtph264depay ! "
        "h264parse ! "
        "rtph264pay pt=96 name=pay0"
    )

    # Set the launch string for the media factory
    factory.set_launch(pipeline_str)
    factory.set_shared(True)

    # Add the media factory to the server
    server.get_mount_points().add_factory("/stream", factory)

    # Attach the server to the main loop
    server.attach(None)
    print("RTSP server started at rtsp://127.0.0.1:8554/stream")

    # Run the main loop
    loop = GLib.MainLoop()
    loop.run()

if __name__ == "__main__":
    main()
