import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';

class MicButton extends StatefulWidget {
  final MicState micState;
  final bool isEnabled;
  final VoidCallback onPressed;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  const MicButton({
    super.key,
    required this.micState,
    required this.isEnabled,
    required this.onPressed,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.micState == MicState.active) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (!widget.isEnabled) return;

    setState(() {
      _isLongPressing = true;
    });
    HapticFeedback.heavyImpact();
    widget.onLongPressStart?.call();
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressing) return;

    setState(() {
      _isLongPressing = false;
    });
    HapticFeedback.lightImpact();
    widget.onLongPressEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.micState == MicState.active;
    final isLoading = widget.micState == MicState.starting ||
        widget.micState == MicState.stopping;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isActive ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Container(
            width: AppConstants.micButtonSize,
            height: AppConstants.micButtonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.isEnabled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isActive
                          ? [Colors.red.shade400, Colors.red.shade700]
                          : [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.7)
                            ],
                    )
                  : null,
              color: widget.isEnabled ? null : Colors.grey.shade700,
              boxShadow: widget.isEnabled && isActive
                  ? [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      )
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.isEnabled && !isLoading
                    ? () {
                        HapticFeedback.mediumImpact();
                        widget.onPressed();
                      }
                    : null,
                onLongPressStart: widget.isEnabled && !isLoading && widget.onLongPressStart != null
                    ? _handleLongPressStart
                    : null,
                onLongPressEnd: widget.onLongPressEnd != null
                    ? _handleLongPressEnd
                    : null,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          )
                        : Icon(
                            isActive ? Icons.mic : Icons.mic_none,
                            size: 48,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _getStatusText(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: isActive ? Colors.red : null,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getStatusText() {
    switch (widget.micState) {
      case MicState.idle:
        return widget.isEnabled ? 'Tap to toggle\nHold to talk' : 'Connect a device first';
      case MicState.starting:
        return 'Starting...';
      case MicState.active:
        return _isLongPressing ? 'LIVE - Release to stop' : 'LIVE - Tap to stop';
      case MicState.stopping:
        return 'Stopping...';
      case MicState.error:
        return 'Error - Tap to retry';
    }
  }
}
