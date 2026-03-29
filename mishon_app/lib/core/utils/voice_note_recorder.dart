import 'voice_note_recorder_io.dart'
    if (dart.library.html) 'voice_note_recorder_web.dart'
    as impl;

export 'voice_note_recording_result.dart' show VoiceNoteRecordingResult;

class VoiceNoteRecorder extends impl.VoiceNoteRecorder {}
