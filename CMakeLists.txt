# SPDX-FileCopyrightText: (C) 2024-2026 Jiri Zaloudek <shokarta@gmail.com> https://www.sfatmt.com
# SPDX-License-Identifier: MIT

cmake_minimum_required(VERSION 3.29)
set(CMAKE_VERBOSE_MAKEFILE ON CACHE BOOL "ON" FORCE)


# Variables needed more than once below
set(MY_APP_PROJECT_NAME "WireGuardClient")
string(TOLOWER ${MY_APP_PROJECT_NAME} MY_APP_PROJECT_NAME_URI)
set(TARGET_NAME "wireGuardClient")
set(PROJECT_VERSION 1.0.0)
set(MY_APP_REVERSE_DNS_IDENTIFIER "com.sfatmt.wireguardclient")

project(${MY_APP_PROJECT_NAME} VERSION ${PROJECT_VERSION})



set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)




find_package(QT NAMES Qt6)		# load Qt CMake Variables (ie: QT_VERSION_MAJOR etc)
find_package(Qt6 REQUIRED COMPONENTS Quick)
find_package(Qt6 REQUIRED COMPONENTS QuickControls2)
find_package(Qt6 REQUIRED COMPONENTS Widgets)
find_package(Qt6 REQUIRED COMPONENTS Core)
find_package(Qt6 REQUIRED COMPONENTS Gui)
find_package(Qt6 REQUIRED COMPONENTS Network)
find_package(Qt6 REQUIRED COMPONENTS Concurrent)


qt_policy(
	SET QTP0002 NEW
)


# Add executable or library
qt_add_executable(${TARGET_NAME}
	main.cpp
	TrayManager.h
	TrayManager.cpp
	VpnProfile.h
	VpnProfilesModel.h
	VpnProfilesModel.cpp
	ServiceController.h
	ServiceController.cpp
)

#set_source_files_properties(Main.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(${TARGET_NAME}
	URI ${TARGET_NAME}
	VERSION ${PROJECT_VERSION}
	RESOURCE_PREFIX /

	QML_FILES
		Main.qml

	RESOURCES
		# images
		resources/app.ico
		resources/icon.rc
		resources/images/i_modify.svg
		resources/images/i_settings.gif
)


#set_target_properties(${TARGET_NAME} PROPERTIES
#	WIN32_EXECUTABLE TRUE
#	#VS_GLOBAL_ApplicationManifest "${CMAKE_CURRENT_SOURCE_DIR}/app.manifest"
#)

target_link_libraries(${TARGET_NAME} PRIVATE Qt6::Quick)
target_link_libraries(${TARGET_NAME} PRIVATE Qt6::QuickControls2)
target_link_libraries(${TARGET_NAME} PRIVATE Qt6::Widgets)
target_link_libraries(${TARGET_NAME} PRIVATE Qt6::Core)
target_link_libraries(${TARGET_NAME} PRIVATE Qt6::Gui)
target_link_libraries(${TARGET_NAME} PRIVATE Qt6::Network)
target_link_libraries(${TARGET_NAME} PRIVATE Qt6::Concurrent)
target_link_libraries(${TARGET_NAME} PRIVATE wlanapi)

target_compile_definitions(${TARGET_NAME} PRIVATE $<$<CONFIG:Debug>:QT_QML_DEBUG>)


set_target_properties(${TARGET_NAME} PROPERTIES
	WIN32_EXECUTABLE TRUE
	QT_WINDOWS_APP_PROJECT_EXECUTION_LEVEL "requireAdministrator"
)

target_sources(
	${TARGET_NAME}
	PRIVATE
		resources/icon.rc
)


	add_custom_command(TARGET ${TARGET_NAME}
		POST_BUILD
		COMMAND
			C:/Qt/${QT_VERSION}/msvc2022_64/bin/windeployqt.exe
			--qmldir "${CMAKE_CURRENT_SOURCE_DIR}"
			"$<TARGET_FILE:${TARGET_NAME}>"
		COMMENT "Running windeployqt"
	)

include(GNUInstallDirs)
install(TARGETS ${TARGET_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

#qt_generate_deploy_app_script(
qt_generate_deploy_qml_app_script(
	TARGET ${TARGET_NAME}
	OUTPUT_SCRIPT deploy_script
	NO_UNSUPPORTED_PLATFORM_ERROR
)

install(SCRIPT ${deploy_script})