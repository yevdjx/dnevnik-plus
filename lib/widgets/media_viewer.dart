import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Plays audio directly from in-memory WAV bytes; avoids a plaintext file.
class _MemoryAudioSource extends StreamAudioSource {
  _MemoryAudioSource(this.bytes);
  final Uint8List bytes;
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final begin = (start ?? 0).clamp(0, bytes.length).toInt();
    final finish = (end ?? bytes.length).clamp(begin, bytes.length).toInt();
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: finish - begin,
      offset: begin,
      stream: Stream.value(bytes.sublist(begin, finish)),
      contentType: 'audio/wav',
    );
  }
}

class JournalAudioPlayer extends StatefulWidget {
  const JournalAudioPlayer({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<JournalAudioPlayer> createState() => _JournalAudioPlayerState();
}

class _JournalAudioPlayerState extends State<JournalAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  Future<void> _initialize() async {
    try {
      await _player.setAudioSource(_MemoryAudioSource(widget.bytes));
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.mic),
    title: const Text('Голосовое сообщение'),
    subtitle: _error == null ? null : Text('Ошибка воспроизведения: $_error'),
    trailing: StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return IconButton(
          tooltip: playing ? 'Пауза' : 'Слушать',
          icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
          onPressed: !_ready ? null : () async {
            if (playing) { await _player.pause(); }
            else {
              if (_player.processingState == ProcessingState.completed) {
                await _player.seek(Duration.zero);
              }
              await _player.play();
            }
          },
        );
      },
    ),
  );
}

/// Video player requires an on-disk file. The temporary plaintext cache is
/// best-effort deleted when closing; crashes may leave a residue in app cache.
class JournalVideoPlayer extends StatefulWidget {
  const JournalVideoPlayer({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<JournalVideoPlayer> createState() => _JournalVideoPlayerState();
}
class _JournalVideoPlayerState extends State<JournalVideoPlayer> {
  File? _file;
  VideoPlayerController? _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  Future<void> _initialize() async {
    try {
      final temp = await getTemporaryDirectory();
      final file = File('${temp.path}/dnevnik_video_${DateTime.now().microsecondsSinceEpoch}.mp4');
      _file = file;
      await file.writeAsBytes(widget.bytes, flush: true);
      final controller = VideoPlayerController.file(file);
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }
  @override
  void dispose() {
    final controller = _controller;
    final file = _file;
    if (controller != null) {
      controller.dispose().then((_) async {
        if (file != null && await file.exists()) await file.delete();
      });
    } else if (file != null) {
      file.delete().catchError((Object _) => file);
    }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) return Text('Видео не открывается: $_error');
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(children: [
      AspectRatio(aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller)),
      TextButton.icon(
        onPressed: () async {
          if (controller.value.isPlaying) { await controller.pause(); }
          else { await controller.play(); }
          if (mounted) setState(() {});
        },
        icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
        label: Text(controller.value.isPlaying ? 'Пауза' : 'Воспроизвести видео'),
      ),
    ]);
  }
}
