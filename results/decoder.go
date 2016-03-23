package results

import (
	"errors"

	"github.com/gogo/protobuf/proto"
	"github.com/mozilla-services/heka/message"
	"github.com/mozilla-services/heka/pipeline"
	"github.com/opsee/basic/schema"
	"github.com/satori/go.uuid"
)

type CloudWatchDecoder struct{}

func newMessage() *pipeline.Message {
	u1 := uuid.NewV4()
	return &pipeline.Message{
		Uuid: u1,
	}
}

func messageFromHttpResponse(response *schema.HttpResponse) (*pipeline.Message, error) {
	msg := newMessage()
	msg.SetType("HttpResponse")
	f, err := pipeline.NewField("code", response.Code, "")
	if err != nil {
		return nil, err
	}
	msg.AddField(f)

	f, err = pipeline.NewField("body", response.Body, "")
	if err != nil {
		return nil, err
	}
	msg.AddField(f)

	f, err = pipeline.NewField("headers", response.Headers, "")
	if err != nil {
		return nil, err
	}
	msg.AddField(f)

	f, err = pipeline.NewField("metrics", response.Metrics, "")
	if err != nil {
		return nil, err
	}
	msg.AddField(f)

	f, err = pipeline.NewField("host", response.Host, "")
	if err != nil {
		return nil, err
	}
	msg.AddField(f)

	return msg, nil
}

func messageFromCloudWatchResponse(response *schema.CloudWatchResponse) (*pipeline.Message, error) {
	msg := newMessage()

	f, err := pipeline.NewField("namespace", response.Namespace, "")
	if err != nil {
		return nil, err
	}
	msg.AddField(f)

	f, err := pipeline.NewField("metrics", response.Metrics, "")
	if err != nil {
		return nil, err
	}
	msg.AddField(f)

	return msg, nil
}

func getMessageFromAny(response *schema.CheckResponse) (*pipeline.Message, error) {
	var (
		msg *pipeline.Message
		err error
	)
	r, err := schema.UnmarshalAny(response.Any)

	switch r := r.(type) {
	default:
		return errors.New("Unable to determine response type.")
	case *schema.HttpResponse:
		msg, err = messageFromHttpResponse(r)
	case *schema.CloudWatchResponse:
		msg, err = messageFromCloudWatchResponse(r)
	}

	return msg, err
}

func getMessageFromReply(response *scheam.CheckResponse) (*pipeline.Message, error) {
	var (
		msg *pipeline.Message
		err error
	)
	r := response.Reply

	switch r := r.(type) {
	default:
		return errors.New("Unable to determine response type.")
	case *schema.HttpResponse:
		msg, err = messageFromHttpResponse(r)
	case *schema.CloudWatchResponse:
		msg, err = messageFromCloudWatchResponse(r)
	}

	return msg, err
}

func messageFromResponse(response *schema.CheckResponse) (*pipeline.Message, error) {
	var (
		err     error
		message *pipeline.Message
	)

	r := nil

	if response.Reply {
		message, err = getMessageFromReply(response)
	} else {
		message, err = getMessageFromAny(response)
	}

	return message, err
}

func (decoder *CloudWatchDecoder) Decode(pack *pipeline.PipelinePack) ([]*pipeline.PipelinePack, error) {
	msgBytes := pack.MsgBytes
	result := &schema.CheckResult{}
	err := proto.Unmarshal(msgBytes, checkResult)
	if err != nil {
		return packs, err
	}

	packs := make([]*pipeline.PipelinePack{}, len(result.Responses))

	for i, resp := range result.Responses {
		message, err := messageFromResponse(resp)
		if err != nil {
			return nil, err
		}

		newPack := pipeline.NewPipelinePack(pack.RecycleChan)
		newPack.Message = message
		packs[i] = newPack
	}

	return packs, nil
}
