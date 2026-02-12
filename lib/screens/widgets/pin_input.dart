import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinInput extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final bool obscureText;
  final TextEditingController? controller;
  final bool enabled;
  final bool autoFocus;
  final String? errorText;
  final VoidCallback? onClear;

  const PinInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.obscureText = false,
    this.controller,
    this.enabled = true,
    this.autoFocus = true,
    this.errorText,
    this.onClear,
  });

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _controllers = List.generate(
      widget.length,
      (index) => TextEditingController(),
    );
    _focusNodes = List.generate(widget.length, (index) => FocusNode());

    // Auto-focus first field if enabled
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focusNodes.isNotEmpty && mounted) {
          _focusNodes[0].requestFocus();
        }
      });
    }

    // Add listeners for backspace detection
    for (int i = 0; i < widget.length; i++) {
      _focusNodes[i].addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void didUpdateWidget(PinInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset error state when errorText changes
    if (oldWidget.errorText != widget.errorText) {
      setState(() {
        _hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (!widget.enabled) return;

    // Clear error state on user input
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }

    if (value.isNotEmpty) {
      // Handle paste scenario (multiple digits at once)
      if (value.length > 1) {
        _handlePaste(value, index);
        return;
      }

      // Move to next field
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last field - unfocus to hide keyboard
        _focusNodes[index].unfocus();
      }
    }

    // Get complete PIN
    String pin = _controllers.map((c) => c.text).join();

    // Notify onChanged
    widget.onChanged?.call(pin);

    // Check if complete
    if (pin.length == widget.length) {
      // Small delay for better UX
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          widget.onCompleted(pin);
        }
      });
    }
  }

  void _handlePaste(String value, int startIndex) {
    // Extract only digits
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Fill fields from current index
    for (
      int i = 0;
      i < digits.length && (startIndex + i) < widget.length;
      i++
    ) {
      _controllers[startIndex + i].text = digits[i];
    }

    // Focus last filled field or complete
    final lastFilledIndex = (startIndex + digits.length - 1).clamp(
      0,
      widget.length - 1,
    );
    if (lastFilledIndex < widget.length - 1) {
      _focusNodes[lastFilledIndex + 1].requestFocus();
    } else {
      _focusNodes[lastFilledIndex].unfocus();
    }

    // Trigger change notification
    _onChanged(
      lastFilledIndex,
      digits.isNotEmpty ? digits[digits.length - 1] : '',
    );
  }

  void _onBackspace(int index) {
    if (!widget.enabled) return;

    // If current field is empty, move to previous field and clear it
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  /// Public method to clear all PIN fields
  void clear() {
    for (var controller in _controllers) {
      controller.clear();
    }
    if (_focusNodes.isNotEmpty && mounted) {
      _focusNodes[0].requestFocus();
    }
    setState(() {
      _hasError = false;
    });
    widget.onClear?.call();
  }

  /// Public method to shake animation on error
  void shake() {
    // TODO: Implement shake animation if needed
    setState(() {
      _hasError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN Input Fields
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive field width
            final availableWidth = constraints.maxWidth;
            final spacing = 8.0;
            final totalSpacing = spacing * (widget.length - 1);
            final fieldWidth = ((availableWidth - totalSpacing) / widget.length)
                .clamp(40.0, 60.0);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < widget.length - 1 ? spacing : 0,
                  ),
                  child: _buildPinField(index, fieldWidth),
                );
              }),
            );
          },
        ),

        // Error Text
        if (widget.errorText != null && widget.errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              widget.errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildPinField(int index, double width) {
    final bool isFocused = _focusNodes[index].hasFocus;
    final bool hasValue = _controllers[index].text.isNotEmpty;
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          // Handle backspace key
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            _onBackspace(index);
          }
        },
        child: Semantics(
          label: 'PIN digit ${index + 1} of ${widget.length}',
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            enabled: widget.enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            obscureText: widget.obscureText,
            style: TextStyle(
              fontSize: width * 0.45, // Responsive font size
              fontWeight: FontWeight.bold,
              color: widget.enabled ? null : Colors.grey[400],
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: widget.enabled
                  ? (isFocused
                        ? theme.primaryColor.withOpacity(0.05)
                        : Colors.grey[50])
                  : Colors.grey[100],
              contentPadding: EdgeInsets.symmetric(vertical: width * 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _hasError
                      ? theme.colorScheme.error
                      : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _hasError
                      ? theme.colorScheme.error
                      : (hasValue
                            ? theme.primaryColor.withOpacity(0.3)
                            : Colors.grey[300]!),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _hasError
                      ? theme.colorScheme.error
                      : theme.primaryColor,
                  width: 2.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            onChanged: (value) => _onChanged(index, value),
            onTap: () {
              // Select all text on tap for easier editing
              if (_controllers[index].text.isNotEmpty) {
                _controllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controllers[index].text.length,
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
