package dev.antigravity.remote

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import kotlin.math.hypot

class FloatingHeadService : Service() {

    private lateinit var windowManager: WindowManager
    private var headView: FrameLayout? = null
    private var dismissView: FrameLayout? = null
    private var statusDot: View? = null
    private var pulseAnimator: ObjectAnimator? = null

    private lateinit var headParams: WindowManager.LayoutParams
    private lateinit var dismissParams: WindowManager.LayoutParams

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f

    private var screenWidth = 0
    private var screenHeight = 0

    companion object {
        const val ACTION_START = "dev.antigravity.remote.ACTION_START"
        const val ACTION_UPDATE_STATUS = "dev.antigravity.remote.ACTION_UPDATE_STATUS"
        const val ACTION_STOP = "dev.antigravity.remote.ACTION_STOP"
        const val EXTRA_STATUS = "extra_status"
        const val EXTRA_TITLE = "extra_title"

        var isRunning = false
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        updateScreenDimensions()

        createFloatingHead()
        createDismissTarget()
        isRunning = true
    }

    private fun dpToPx(dp: Int): Int {
        val density = resources.displayMetrics.density
        return (dp * density).toInt()
    }

    private fun updateScreenDimensions() {
        val metrics = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(metrics)
        screenWidth = metrics.widthPixels
        screenHeight = metrics.heightPixels
    }

    private fun createFloatingHead() {
        val size = dpToPx(56)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        headParams = WindowManager.LayoutParams(
            size,
            size,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = screenWidth - size - dpToPx(16)
            y = screenHeight / 3
        }

        val frame = FrameLayout(this)
        frame.layoutParams = FrameLayout.LayoutParams(size, size)

        // Background: Round dark oval with cyan neon border
        val bgDrawable = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#181822"))
            setStroke(dpToPx(2), Color.parseColor("#38BDF8"))
        }
        frame.background = bgDrawable
        frame.elevation = dpToPx(8).toFloat()

        // Center Terminal Icon: ">_" bold cyan font
        val iconText = TextView(this).apply {
            text = ">_"
            textSize = 19f
            setTypeface(Typeface.MONOSPACE, Typeface.BOLD)
            setTextColor(Color.parseColor("#38BDF8"))
            gravity = Gravity.CENTER
        }
        val iconParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ).apply {
            gravity = Gravity.CENTER
        }
        frame.addView(iconText, iconParams)

        // Status Dot in bottom right corner
        val dotSize = dpToPx(12)
        statusDot = View(this).apply {
            val dotBg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#34D399")) // Green default
                setStroke(dpToPx(1), Color.parseColor("#181822"))
            }
            background = dotBg
        }
        val dotParams = FrameLayout.LayoutParams(dotSize, dotSize).apply {
            gravity = Gravity.BOTTOM or Gravity.END
            setMargins(0, 0, dpToPx(4), dpToPx(4))
        }
        frame.addView(statusDot, dotParams)

        // Attach Touch Listener
        frame.setOnTouchListener(object : View.OnTouchListener {
            override fun onTouch(v: View?, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = headParams.x
                        initialY = headParams.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        dismissView?.visibility = View.VISIBLE
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        headParams.x = initialX + dx
                        headParams.y = initialY + dy
                        windowManager.updateViewLayout(frame, headParams)

                        // Check if hovering near dismiss target (bottom center)
                        val dismissCenterX = screenWidth / 2
                        val dismissCenterY = screenHeight - dpToPx(60)
                        val headCenterX = headParams.x + size / 2
                        val headCenterY = headParams.y + size / 2
                        val distance = hypot(
                            (headCenterX - dismissCenterX).toDouble(),
                            (headCenterY - dismissCenterY).toDouble()
                        )

                        if (distance < dpToPx(70)) {
                            dismissView?.scaleX = 1.25f
                            dismissView?.scaleY = 1.25f
                        } else {
                            dismissView?.scaleX = 1.0f
                            dismissView?.scaleY = 1.0f
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        dismissView?.visibility = View.GONE
                        val totalDrag = hypot(
                            (event.rawX - initialTouchX).toDouble(),
                            (event.rawY - initialTouchY).toDouble()
                        )

                        // 1. Click event
                        if (totalDrag < dpToPx(10)) {
                            openMainActivity()
                            return true
                        }

                        // 2. Dismiss event
                        val dismissCenterX = screenWidth / 2
                        val dismissCenterY = screenHeight - dpToPx(60)
                        val headCenterX = headParams.x + size / 2
                        val headCenterY = headParams.y + size / 2
                        val distance = hypot(
                            (headCenterX - dismissCenterX).toDouble(),
                            (headCenterY - dismissCenterY).toDouble()
                        )
                        if (distance < dpToPx(70)) {
                            stopSelf()
                            return true
                        }

                        // 3. Snap to nearest edge (left or right)
                        val midX = screenWidth / 2
                        val targetX = if (headParams.x + size / 2 < midX) {
                            dpToPx(12) // Left edge
                        } else {
                            screenWidth - size - dpToPx(12) // Right edge
                        }
                        animateSnap(headParams.x, targetX)
                        return true
                    }
                }
                return false
            }
        })

        headView = frame
        windowManager.addView(frame, headParams)
    }

    private fun animateSnap(fromX: Int, toX: Int) {
        val animator = ValueAnimator.ofInt(fromX, toX).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                headParams.x = anim.animatedValue as Int
                headView?.let { windowManager.updateViewLayout(it, headParams) }
            }
        }
        animator.start()
    }

    private fun createDismissTarget() {
        val size = dpToPx(64)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        dismissParams = WindowManager.LayoutParams(
            size,
            size,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dpToPx(40)
        }

        val frame = FrameLayout(this).apply {
            val bg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#E11D48")) // Red
                setStroke(dpToPx(2), Color.WHITE)
            }
            background = bg
            elevation = dpToPx(10).toFloat()
            visibility = View.GONE
        }

        val closeText = TextView(this).apply {
            text = "✕"
            textSize = 24f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        }
        frame.addView(closeText, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        dismissView = frame
        windowManager.addView(frame, dismissParams)
    }

    private fun openMainActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun updateStatus(status: String) {
        pulseAnimator?.cancel()
        val dot = statusDot ?: return

        when (status.lowercase()) {
            "thinking" -> {
                (dot.background as? GradientDrawable)?.setColor(Color.parseColor("#FBBF24")) // Yellow
                pulseAnimator = ObjectAnimator.ofFloat(dot, "alpha", 1.0f, 0.2f).apply {
                    duration = 600
                    repeatMode = ValueAnimator.REVERSE
                    repeatCount = ValueAnimator.INFINITE
                    start()
                }
            }
            "offline" -> {
                dot.alpha = 1.0f
                (dot.background as? GradientDrawable)?.setColor(Color.parseColor("#EF4444")) // Red
            }
            else -> {
                dot.alpha = 1.0f
                (dot.background as? GradientDrawable)?.setColor(Color.parseColor("#34D399")) // Green
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE_STATUS -> {
                val status = intent.getStringExtra(EXTRA_STATUS) ?: "online"
                updateStatus(status)
            }
            ACTION_STOP -> {
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        pulseAnimator?.cancel()
        headView?.let {
            try {
                windowManager.removeView(it)
            } catch (e: Exception) {
                // Ignore
            }
        }
        dismissView?.let {
            try {
                windowManager.removeView(it)
            } catch (e: Exception) {
                // Ignore
            }
        }
        isRunning = false
    }
}
