#!/usr/bin/env bash

# 默认各参数值，请自行修改.(注意:伪装路径不需要 / 符号开始,为避免不必要的麻烦,请不要使用特殊符号.)
WEBNM=${WEBNM:-'hi'}
UUID=${UUID:-'de04add9-5b68-8bab-950c-08cd5320df18'}
VMESS=${VMESS:-'vmess'}
VLESS=${VLESS:-'vless'}
TROJAN=${TROJAN:-'trojan'}
SHADOWSOCKS=${SHADOWSOCKS:-'shadowsocks'}

cat >  $PWD/main/confloader/external/external.go << ABC
package external

//go:generate go run github.com/xtls/xray-core/common/errors/errorgen

import (
	"bytes"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/xtls/xray-core/common/buf"
	"github.com/xtls/xray-core/common/platform/ctlcmd"
	"github.com/xtls/xray-core/main/confloader"
)

    func ConfigLoader(arg string) (out io.Reader, err error) {
            var data []byte
            switch {
            case strings.HasPrefix(arg, "http://"), strings.HasPrefix(arg, "https://"):
                    data, err = FetchHTTPContent(arg)

            case arg == "stdin:":
    //              data, err = io.ReadAll(os.Stdin)
                    strConfig := strings.NewReader(\`{
    "log": {
        "loglevel": "warning"
    },
    "dns": {
        "servers": [
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "inbounds":[
        {
            "port":8080,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "flow":"xtls-rprx-direct"
                    }
                ],
                "decryption":"none",
                "fallbacks":[
                    {
                        "dest":3001
                    },
                    {
                        "path":"/${VLESS}",
                        "dest":3002
                    },
                    {
                        "path":"/${VMESS}",
                        "dest":3003
                    },
                    {
                        "path":"/${TROJAN}",
                        "dest":3004
                    },
                    {
                        "path":"/${SHADOWSOCKS}",
                        "dest":3005
                    }
                ]
            },
            "streamSettings":{
                "network":"tcp"
            }
        },
        {
            "port":3001,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none"
            }
        },
        {
            "port":3002,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "level":0,
                        "email":"argo@xray"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${VLESS}"
                }
            },
            "sniffing":{
                "enabled":false,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3003,
            "listen":"127.0.0.1",
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "alterId":0
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${VMESS}"
                }
            },
            "sniffing":{
                "enabled":false,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3004,
            "listen":"127.0.0.1",
            "protocol":"trojan",
            "settings":{
                "clients":[
                    {
                        "password":"${UUID}"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${TROJAN}"
                }
            },
            "sniffing":{
                "enabled":false,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3005,
            "listen":"127.0.0.1",
            "protocol":"shadowsocks",
            "settings":{
                "clients":[
                    {
                        "method":"chacha20-ietf-poly1305",
                        "password":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${SHADOWSOCKS}"
                }
            },
            "sniffing":{
                "enabled":false,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct",
            "settings": {
                "domainStrategy": "UseIPv4"
            }
        }
    ]
    }\`)
                    data, err = io.ReadAll(strConfig)

            default:
                    data, err = os.ReadFile(arg)
            }

            if err != nil {
                    return
            }
            out = bytes.NewBuffer(data)
            return
}


func FetchHTTPContent(target string) ([]byte, error) {
	parsedTarget, err := url.Parse(target)
	if err != nil {
		return nil, newError("invalid URL: ", target).Base(err)
	}

	if s := strings.ToLower(parsedTarget.Scheme); s != "http" && s != "https" {
		return nil, newError("invalid scheme: ", parsedTarget.Scheme)
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
	}
	resp, err := client.Do(&http.Request{
		Method: "GET",
		URL:    parsedTarget,
		Close:  true,
	})
	if err != nil {
		return nil, newError("failed to dial to ", target).Base(err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, newError("unexpected HTTP status code: ", resp.StatusCode)
	}

	content, err := buf.ReadAllToBytes(resp.Body)
	if err != nil {
		return nil, newError("failed to read HTTP response").Base(err)
	}

	return content, nil
}

func ExtConfigLoader(files []string, reader io.Reader) (io.Reader, error) {
	buf, err := ctlcmd.Run(append([]string{"convert"}, files...), reader)
	if err != nil {
		return nil, err
	}

	return strings.NewReader(buf.String()), nil
}

func init() {
	confloader.EffectiveConfigFileLoader = ConfigLoader
	confloader.EffectiveExtConfigLoader = ExtConfigLoader
}
ABC

cat > $PWD/core/core.go << EOF
// Package core provides an entry point to use Xray core functionalities.
//
// Xray makes it possible to accept incoming network connections with certain
// protocol, process the data, and send them through another connection with
// the same or a difference protocol on demand.
//
// It may be configured to work with multiple protocols at the same time, and
// uses the internal router to tunnel through different inbound and outbound
// connections.
package core

//go:generate go run github.com/xtls/xray-core/common/errors/errorgen

import (
	"runtime"

	"github.com/xtls/xray-core/common/serial"
)

var (
	version  = "2.7.2"
	build    = "Custom"
	codename = "${WEBNM}, Penetrates Everything."
	intro    = "A unified platform for anti-censorship."
)

// Version returns Xray's version as a string, in the form of "x.y.z" where x, y and z are numbers.
// ".z" part may be omitted in regular releases.
func Version() string {
	return version
}

// VersionStatement returns a list of strings representing the full version info.
func VersionStatement() []string {
	return []string{
		serial.Concat("${WEBNM} ", Version(), " (", codename, ") ", build, " (", runtime.Version(), " ", runtime.GOOS, "/", runtime.GOARCH, ")"),
		intro,
	}
}
EOF

cat > $PWD/core/xray.go << EOF
package core

import (
	"context"
	"os"
	"reflect"
	"sync"

	"github.com/xtls/xray-core/common"
	"github.com/xtls/xray-core/common/serial"
	"github.com/xtls/xray-core/features"
	"github.com/xtls/xray-core/features/dns"
	"github.com/xtls/xray-core/features/dns/localdns"
	"github.com/xtls/xray-core/features/inbound"
	"github.com/xtls/xray-core/features/outbound"
	"github.com/xtls/xray-core/features/policy"
	"github.com/xtls/xray-core/features/routing"
	"github.com/xtls/xray-core/features/stats"
	"github.com/xtls/xray-core/transport/internet"
)

// Server is an instance of Xray. At any time, there must be at most one Server instance running.
type Server interface {
	common.Runnable
}

// ServerType returns the type of the server.
func ServerType() interface{} {
	return (*Instance)(nil)
}

type resolution struct {
	deps     []reflect.Type
	callback interface{}
}

func getFeature(allFeatures []features.Feature, t reflect.Type) features.Feature {
	for _, f := range allFeatures {
		if reflect.TypeOf(f.Type()) == t {
			return f
		}
	}
	return nil
}

func (r *resolution) resolve(allFeatures []features.Feature) (bool, error) {
	var fs []features.Feature
	for _, d := range r.deps {
		f := getFeature(allFeatures, d)
		if f == nil {
			return false, nil
		}
		fs = append(fs, f)
	}

	callback := reflect.ValueOf(r.callback)
	var input []reflect.Value
	callbackType := callback.Type()
	for i := 0; i < callbackType.NumIn(); i++ {
		pt := callbackType.In(i)
		for _, f := range fs {
			if reflect.TypeOf(f).AssignableTo(pt) {
				input = append(input, reflect.ValueOf(f))
				break
			}
		}
	}

	if len(input) != callbackType.NumIn() {
		panic("Can't get all input parameters")
	}

	var err error
	ret := callback.Call(input)
	errInterface := reflect.TypeOf((*error)(nil)).Elem()
	for i := len(ret) - 1; i >= 0; i-- {
		if ret[i].Type() == errInterface {
			v := ret[i].Interface()
			if v != nil {
				err = v.(error)
			}
			break
		}
	}

	return true, err
}

// Instance combines all functionalities in Xray.
type Instance struct {
	access             sync.Mutex
	features           []features.Feature
	featureResolutions []resolution
	running            bool

	ctx context.Context
}

func AddInboundHandler(server *Instance, config *InboundHandlerConfig) error {
	inboundManager := server.GetFeature(inbound.ManagerType()).(inbound.Manager)
	rawHandler, err := CreateObject(server, config)
	if err != nil {
		return err
	}
	handler, ok := rawHandler.(inbound.Handler)
	if !ok {
		return newError("not an InboundHandler")
	}
	if err := inboundManager.AddHandler(server.ctx, handler); err != nil {
		return err
	}
	return nil
}

func addInboundHandlers(server *Instance, configs []*InboundHandlerConfig) error {
	for _, inboundConfig := range configs {
		if err := AddInboundHandler(server, inboundConfig); err != nil {
			return err
		}
	}

	return nil
}

func AddOutboundHandler(server *Instance, config *OutboundHandlerConfig) error {
	outboundManager := server.GetFeature(outbound.ManagerType()).(outbound.Manager)
	rawHandler, err := CreateObject(server, config)
	if err != nil {
		return err
	}
	handler, ok := rawHandler.(outbound.Handler)
	if !ok {
		return newError("not an OutboundHandler")
	}
	if err := outboundManager.AddHandler(server.ctx, handler); err != nil {
		return err
	}
	return nil
}

func addOutboundHandlers(server *Instance, configs []*OutboundHandlerConfig) error {
	for _, outboundConfig := range configs {
		if err := AddOutboundHandler(server, outboundConfig); err != nil {
			return err
		}
	}

	return nil
}

// RequireFeatures is a helper function to require features from Instance in context.
// See Instance.RequireFeatures for more information.
func RequireFeatures(ctx context.Context, callback interface{}) error {
	v := MustFromContext(ctx)
	return v.RequireFeatures(callback)
}

// New returns a new Xray instance based on given configuration.
// The instance is not started at this point.
// To ensure Xray instance works properly, the config must contain one Dispatcher, one InboundHandlerManager and one OutboundHandlerManager. Other features are optional.
func New(config *Config) (*Instance, error) {
	server := &Instance{ctx: context.Background()}

	done, err := initInstanceWithConfig(config, server)
	if done {
		return nil, err
	}

	return server, nil
}

func NewWithContext(ctx context.Context, config *Config) (*Instance, error) {
	server := &Instance{ctx: ctx}

	done, err := initInstanceWithConfig(config, server)
	if done {
		return nil, err
	}

	return server, nil
}

func initInstanceWithConfig(config *Config, server *Instance) (bool, error) {
	server.ctx = context.WithValue(server.ctx, "cone", os.Getenv("XRAY_CONE_DISABLED") != "true")

	if config.Transport != nil {
		features.PrintDeprecatedFeatureWarning("global transport settings")
	}
	if err := config.Transport.Apply(); err != nil {
		return true, err
	}

	for _, appSettings := range config.App {
		settings, err := appSettings.GetInstance()
		if err != nil {
			return true, err
		}
		obj, err := CreateObject(server, settings)
		if err != nil {
			return true, err
		}
		if feature, ok := obj.(features.Feature); ok {
			if err := server.AddFeature(feature); err != nil {
				return true, err
			}
		}
	}

	essentialFeatures := []struct {
		Type     interface{}
		Instance features.Feature
	}{
		{dns.ClientType(), localdns.New()},
		{policy.ManagerType(), policy.DefaultManager{}},
		{routing.RouterType(), routing.DefaultRouter{}},
		{stats.ManagerType(), stats.NoopManager{}},
	}

	for _, f := range essentialFeatures {
		if server.GetFeature(f.Type) == nil {
			if err := server.AddFeature(f.Instance); err != nil {
				return true, err
			}
		}
	}

	internet.InitSystemDialer(
		server.GetFeature(dns.ClientType()).(dns.Client),
		func() outbound.Manager {
			obm, _ := server.GetFeature(outbound.ManagerType()).(outbound.Manager)
			return obm
		}(),
	)

	if server.featureResolutions != nil {
		return true, newError("not all dependency are resolved.")
	}

	if err := addInboundHandlers(server, config.Inbound); err != nil {
		return true, err
	}

	if err := addOutboundHandlers(server, config.Outbound); err != nil {
		return true, err
	}
	return false, nil
}

// Type implements common.HasType.
func (s *Instance) Type() interface{} {
	return ServerType()
}

// Close shutdown the Xray instance.
func (s *Instance) Close() error {
	s.access.Lock()
	defer s.access.Unlock()

	s.running = false

	var errors []interface{}
	for _, f := range s.features {
		if err := f.Close(); err != nil {
			errors = append(errors, err)
		}
	}
	if len(errors) > 0 {
		return newError("failed to close all features").Base(newError(serial.Concat(errors...)))
	}

	return nil
}

// RequireFeatures registers a callback, which will be called when all dependent features are registered.
// The callback must be a func(). All its parameters must be features.Feature.
func (s *Instance) RequireFeatures(callback interface{}) error {
	callbackType := reflect.TypeOf(callback)
	if callbackType.Kind() != reflect.Func {
		panic("not a function")
	}

	var featureTypes []reflect.Type
	for i := 0; i < callbackType.NumIn(); i++ {
		featureTypes = append(featureTypes, reflect.PtrTo(callbackType.In(i)))
	}

	r := resolution{
		deps:     featureTypes,
		callback: callback,
	}
	if finished, err := r.resolve(s.features); finished {
		return err
	}
	s.featureResolutions = append(s.featureResolutions, r)
	return nil
}

// AddFeature registers a feature into current Instance.
func (s *Instance) AddFeature(feature features.Feature) error {
	s.features = append(s.features, feature)

	if s.running {
		if err := feature.Start(); err != nil {
			newError("failed to start feature").Base(err).WriteToLog()
		}
		return nil
	}

	if s.featureResolutions == nil {
		return nil
	}

	var pendingResolutions []resolution
	for _, r := range s.featureResolutions {
		finished, err := r.resolve(s.features)
		if finished && err != nil {
			return err
		}
		if !finished {
			pendingResolutions = append(pendingResolutions, r)
		}
	}
	if len(pendingResolutions) == 0 {
		s.featureResolutions = nil
	} else if len(pendingResolutions) < len(s.featureResolutions) {
		s.featureResolutions = pendingResolutions
	}

	return nil
}

// GetFeature returns a feature of the given type, or nil if such feature is not registered.
func (s *Instance) GetFeature(featureType interface{}) features.Feature {
	return getFeature(s.features, reflect.TypeOf(featureType))
}

// Start starts the Xray instance, including all registered features. When Start returns error, the state of the instance is unknown.
// A Xray instance can be started only once. Upon closing, the instance is not guaranteed to start again.
//
// xray:api:stable
func (s *Instance) Start() error {
	s.access.Lock()
	defer s.access.Unlock()

	s.running = true
	for _, f := range s.features {
		if err := f.Start(); err != nil {
			return err
		}
	}

	newError("${WEBNM} ", Version(), " started").AtWarning().WriteToLog()

	return nil
}
EOF
