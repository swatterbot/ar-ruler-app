// android/app/src/main/java/com/example/ar_ruler/ar/ArCoreFragment.kt
package com.example.ar_ruler.ar

import android.content.Context
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.ar_ruler.R
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import com.google.ar.core.exceptions.CameraNotAvailableException
import timber.log.Timber

class ArCoreFragment : Fragment() {

    private lateinit var glSurfaceView: GLSurfaceView
    private var session: Session? = null
    private var installRequested = false
    private val renderer = ArCoreRenderer(this) // свой рендерер

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_ar_core, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        glSurfaceView = view.findViewById(R.id.gl_surface_view)
        // Настройка GLSurfaceView
        glSurfaceView.setEGLContextClientVersion(2)
        glSurfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0) // RGBA, depth
        glSurfaceView.setRenderer(renderer)
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
    }

    override fun onResume() {
        super.onResume()
        createSession()
    }

    private fun createSession() {
        if (session == null) {
            try {
                val arCoreApk = ArCoreApk.getInstance()
                if (arCoreApk.checkAvailability(requireContext()) == ArCoreApk.Availability.SUPPORTED_INSTALLED) {
                    // Создаём сессию
                    session = Session(requireContext())
                    configureSession()
                } else {
                    // ARCore не установлен или не поддерживается
                    Timber.e("ARCore not supported")
                }
            } catch (e: UnavailableArcoreNotInstalledException) {
                Timber.e("ARCore not installed")
            } catch (e: UnavailableUserDeclinedInstallationException) {
                Timber.e("User declined ARCore installation")
            } catch (e: Exception) {
                Timber.e(e, "Failed to create AR session")
            }
        }

        try {
            session?.resume()
            glSurfaceView.onResume()
        } catch (e: CameraNotAvailableException) {
            Timber.e(e, "Camera not available")
        }
    }

    private fun configureSession() {
        val config = Config(session)
        // Настройка: плоскости, освещение
        config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
        config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
        config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
        session?.configure(config)
    }

    override fun onPause() {
        super.onPause()
        glSurfaceView.onPause()
        session?.pause()
    }

    override fun onDestroy() {
        super.onDestroy()
        session?.close()
    }

    fun getSession(): Session? = session

    // Методы для взаимодействия с Flutter
    fun setMode(mode: String) {
        renderer.setMode(mode)
    }

    fun reset() {
        renderer.reset()
    }

    fun takeMeasurement() {
        renderer.takeMeasurement()
    }

    // Обработка касания (передаётся из Activity)
    fun handleTap(x: Float, y: Float) {
        session?.let { session ->
            val frame = session.update()
            val hitResults = frame.hitTest(x, y)
            // Фильтруем только плоскости и feature points
            val hit = hitResults.firstOrNull { it.trackable is Plane && (it.trackable as Plane).isPoseInPolygon(it.hitPose) }
                    ?: hitResults.firstOrNull { it.trackable is Point }
            hit?.let {
                renderer.addPoint(it.hitPose)
            }
        }
    }
}
